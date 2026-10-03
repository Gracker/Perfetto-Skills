"""SmartPerfetto's process identity gate as ported to the portable runtime.

Cases follow SmartPerfetto's identityGate.test.ts and the resolver
normalization in skillExecutor.ts, so both products decide alike.
"""

import unittest
from unittest import mock

from tests.support import load_skill_script


load_skill_script("_common")
identity = load_skill_script("process_identity")


def verified(**overrides):
    return {
        "status": "verified", "requestedName": "com.example", "canonicalPackageName": "com.example",
        "recommendedProcessNameParam": "com.real.process", "upids": [42], "confidenceScore": 90,
        "rawStatus": "confirmed", "evidenceSources": ["android_process_metadata.package_name"],
        "warnings": [], "candidates": [], **overrides,
    }


class FixedGate(identity.IdentityGate):
    """The gate with SmartPerfetto's injected `resolve` instead of the resolver Skill."""

    def __init__(self, resolve):
        super().__init__(mock.Mock(), mock.Mock())
        self.resolve = resolve


def skill(**overrides):
    return {"id": "test_skill", **overrides}


def row(**overrides):
    return {
        "rank": 1, "confidence_score": 100, "identity_status": "confirmed",
        "canonical_package_name": "com.example", "recommended_process_name_param": "com.example",
        "upid": 42, "pid": 4242, "process_name": "com.example",
        "target_match_sources": "process.name", "identity_warning": "ok", **overrides,
    }


class IdentityGateTest(unittest.TestCase):
    def test_allowed_invocations_without_a_target_do_not_resolve(self) -> None:
        for policy in ("none", "exempt", "verify_if_present"):
            with self.subTest(policy=policy):
                resolve = mock.Mock(return_value=verified())
                result = FixedGate(resolve).apply(skill(identity={"policy": policy}), {}, {"context": "kept"})
                self.assertTrue(result.allowed)
                self.assertEqual(result.scope.mode, "unscoped")
                self.assertIsNone(result.scope.verified_identity())
                resolve.assert_not_called()

    def test_the_resolver_skill_is_always_exempt(self) -> None:
        resolve = mock.Mock()
        result = FixedGate(resolve).apply(
            {"id": "process_identity_resolver", "identity": {"policy": "required"}}, {"package": "x"}, {},
        )
        self.assertTrue(result.allowed)
        resolve.assert_not_called()

    def test_required_without_a_target_is_refused(self) -> None:
        result = FixedGate(mock.Mock()).apply(
            skill(identity={"policy": "required", "scope": "process"}), {}, {"__skipIdentityGate": True},
        )
        self.assertFalse(result.allowed)
        self.assertEqual(
            result.error,
            'Process identity is required before running skill "test_skill", but no package/process/upid target was provided.',
        )

    def test_verified_identity_rewrites_aliases(self) -> None:
        result = FixedGate(lambda _target: verified()).apply(
            skill(identity={
                "policy": "required", "scope": "process", "aliases": ["package", "process_name"],
                "rewriteTo": "recommended_process_name_param",
            }),
            {"package": "com.example", "process_name": "com.example"}, {},
        )
        self.assertTrue(result.allowed)
        self.assertEqual(result.params, {"package": "com.real.process", "process_name": "com.real.process"})
        self.assertEqual(result.evidence()["status"], "resolved")
        self.assertEqual(result.evidence()["target"], "com.real.process")

    def test_a_verified_alias_fills_the_declared_name_input_and_leaves_the_undeclared_one(self) -> None:
        result = FixedGate(lambda _target: verified()).apply(
            skill(
                identity={"policy": "verify_if_present", "aliases": ["package", "process_name"]},
                inputs=[{"name": "package"}],
            ),
            {"process_name": "com.example"}, {},
        )
        self.assertTrue(result.allowed)
        self.assertEqual(result.params, {"package": "com.real.process"})

    def test_an_ambiguous_target_is_refused_with_its_status_and_confidence(self) -> None:
        result = FixedGate(lambda _target: verified(status="ambiguous", confidenceScore=30, rawStatus="weak_match")).apply(
            skill(identity={"policy": "verify_if_present"}), {"package": "com.example"}, {},
        )
        self.assertFalse(result.allowed)
        self.assertEqual(
            result.error, 'Process identity could not be verified for skill "test_skill": status=ambiguous, confidence=30',
        )
        self.assertEqual(result.evidence()["status"], "ambiguous")

    def test_a_score_below_min_confidence_is_not_verified(self) -> None:
        result = FixedGate(lambda _target: verified(confidenceScore=60)).apply(
            skill(identity={"policy": "verify_if_present", "minConfidence": 80}), {"package": "com.example"}, {},
        )
        self.assertFalse(result.allowed)
        self.assertIn("status=verified, confidence=60", result.error)

    def test_a_resolver_failure_is_admitted_only_under_verify_if_present(self) -> None:
        failed = verified(status="unresolved", upids=[], candidates=[], confidenceScore=0, resolverError="module unavailable")
        allowed = FixedGate(lambda _target: failed).apply(
            skill(identity={"policy": "verify_if_present"}), {"package": "com.example"}, {},
        )
        self.assertTrue(allowed.allowed)
        self.assertIn("resolver failed (module unavailable)", allowed.warning)
        self.assertEqual(allowed.scope.mode, "named")
        record = allowed.evidence()
        self.assertEqual((record["status"], record["target"]), ("unresolved", "com.example"))
        refused = FixedGate(lambda _target: failed).apply(
            skill(identity={"policy": "required"}), {"package": "com.example"}, {},
        )
        self.assertFalse(refused.allowed)
        self.assertEqual(
            refused.error, 'Process identity could not be verified for skill "test_skill": resolver failed (module unavailable)',
        )
        for selector in ({"upid": 42}, {"pid": 4242}):
            self.assertFalse(FixedGate(lambda _target: failed).apply(
                skill(identity={"policy": "verify_if_present"}), {"package": "com.example", **selector}, {},
            ).allowed)

    def test_a_child_reuses_only_a_verified_named_identity(self) -> None:
        failed = verified(status="unresolved", upids=[], candidates=[], confidenceScore=0, resolverError="temporarily")
        results = iter([failed])
        gate = FixedGate(lambda _target: next(results, None) or verified())
        overview = gate.apply(
            skill(identity={"policy": "verify_if_present"}), {"package": "com.example"}, {},
        )
        recover = mock.Mock(return_value=verified())
        gate.resolve = recover
        child = gate.apply(skill(identity={"policy": "required"}), {"package": "com.example"}, {}, overview.scope)
        recover.assert_called_once()
        self.assertTrue(child.allowed)
        self.assertIsNot(child.scope, overview.scope)
        reuse = mock.Mock(return_value=verified())
        gate.resolve = reuse
        following = gate.apply(skill(identity={"policy": "required"}), {"package": "com.example"}, {}, child.scope)
        self.assertTrue(following.allowed)
        self.assertIs(following.scope, child.scope)
        reuse.assert_not_called()
        # A new thread target is resolved again even inside the same named scope.
        thread = mock.Mock(return_value=verified())
        gate.resolve = thread
        gate.apply(
            skill(identity={"policy": "required"}, inputs=[{"name": "thread_name"}]),
            {"package": "com.example", "thread_name": "RenderThread"}, {}, child.scope,
        )
        thread.assert_called_once()

    def test_a_forged_or_foreign_scope_is_untrusted(self) -> None:
        forged = identity.IdentityScope("named", "com.example", ({"requestedName": "com.example"}, verified()))
        result = FixedGate(mock.Mock()).apply(skill(identity={"policy": "required"}), {"package": "com.example"}, {}, forged)
        self.assertFalse(result.allowed)
        self.assertIn("untrusted", result.error)
        # A scope another gate (another trace or side) issued carries no identity here.
        other = FixedGate(lambda _target: verified()).apply(
            skill(identity={"policy": "required"}), {"package": "com.example"}, {},
        )
        resolve = mock.Mock(return_value=verified())
        result = FixedGate(resolve).apply(skill(identity={"policy": "required"}), {"package": "com.example"}, {}, other.scope)
        self.assertFalse(result.allowed)
        self.assertIn("different trace/side", result.error)
        resolve.assert_not_called()

    def test_explicit_selectors_are_validated_and_a_verified_pid_scopes_exactly(self) -> None:
        exact = verified(recommendedProcessNameParam="com.example", candidates=[
            {"rank": 1, "confidenceScore": 100, "upid": 42, "pid": 4242, "processName": "com.example",
             "canonicalPackageName": "com.example"},
        ])
        target_skill = skill(identity={"policy": "verify_if_present"}, inputs=[{"name": "package", "default": "com.default"}])
        for params in ({"upid": 0}, {"upid": "0"}, {"pid": 0}, {"upid": 42, "pid": 0}, {"upid": -1}):
            with self.subTest(params=params):
                resolve = mock.Mock(return_value=exact)
                result = FixedGate(resolve).apply(target_skill, params, {"package": "com.default"})
                self.assertFalse(result.allowed)
                self.assertIn("expected a positive safe integer", result.error)
                resolve.assert_not_called()
        # A verified PID issues an exact UPID scope, as in SmartPerfetto; the
        # PID and UPID are different numbers.
        resolve = mock.Mock(return_value=exact)
        result = FixedGate(resolve).apply(target_skill, {"pid": 4242}, {"package": "com.default"})
        resolve.assert_called_once_with({"pid": 4242})
        self.assertTrue(result.allowed)
        self.assertEqual((result.scope.mode, result.scope.upid), ("exact_upid", 42))
        self.assertNotIn("pid", result.params)
        reused = verified(upids=[42, 43], candidates=[
            {"rank": 1, "confidenceScore": 100, "pid": 4242, "upid": 42},
            {"rank": 2, "confidenceScore": 100, "pid": 4242, "upid": 43},
        ])
        result = FixedGate(lambda _target: reused).apply(target_skill, {"pid": 4242}, {})
        self.assertIn("Explicit PID must resolve to one verified UPID", result.error)

    def test_an_undeclared_thread_selector_is_refused_before_resolution(self) -> None:
        resolve = mock.Mock()
        result = FixedGate(resolve).apply(
            skill(identity={"policy": "verify_if_present"}), {"upid": 42, "thread_name": "RenderThread"}, {},
        )
        self.assertEqual(result.error, "Skill does not declare a thread filter input: thread_name")
        resolve.assert_not_called()

    def test_conflicting_name_aliases_are_refused(self) -> None:
        result = FixedGate(lambda _target: verified(candidates=[])).apply(
            skill(identity={"policy": "verify_if_present"}), {"package": "com.example", "process_name": "other"}, {},
        )
        self.assertEqual(result.error, "Explicit process selector aliases conflict")

    def test_inherited_names_target_only_without_an_explicit_selector(self) -> None:
        config = {"policy": "verify_if_present", "aliases": ["package"]}
        self.assertEqual(identity.extract_target({}, {"package": "com.parent"}, config)["requestedName"], "com.parent")
        self.assertNotIn("requestedName", identity.extract_target({"upid": 7}, {"package": "com.parent"}, config))


class ResolutionTest(unittest.TestCase):
    """resolveProcessIdentityForGate's normalization over resolver rows."""

    def resolve(self, rows, target=None, *, success=True, pid=(1, 42)):
        target = target or {"requestedName": "com.example"}
        return identity.resolve(target, lambda _params: (success, rows, None if success else "boom"), lambda _pid: pid)

    def test_a_confirmed_unique_candidate_is_verified(self) -> None:
        resolution = self.resolve([row()])
        self.assertEqual((resolution["status"], resolution["upids"], resolution["warnings"]), ("verified", [42], []))

    def test_close_candidates_need_confirmation_unless_only_the_top_is_the_exact_name(self) -> None:
        close = [row(), row(upid=43, process_name="com.example:remote", recommended_process_name_param="com.example:remote", confidence_score=90)]
        self.assertEqual(self.resolve(close)["status"], "verified")
        same = [row(), row(upid=43, confidence_score=95)]
        resolution = self.resolve(same)
        self.assertEqual(resolution["status"], "ambiguous")
        self.assertIn("multiple close process identity candidates require manual confirmation", resolution["warnings"])
        persistent = [row(process_name="com.google.android.gms.persistent", recommended_process_name_param="com.google.android.gms.persistent"),
                      row(upid=43, process_name="com.google.android.gms", recommended_process_name_param="com.google.android.gms")]
        self.assertEqual(self.resolve(persistent, {"requestedName": "com.google.android.gms"})["status"], "ambiguous")

    def test_row_warnings_probable_and_thread_only_matches_are_not_verified(self) -> None:
        for rows, target, warning in (
            ([row(identity_warning="shared uid")], None, "shared uid"),
            ([row(identity_status="probable")], None, "probable identity match requires additional confirmation before parameter rewrite"),
            ([row(target_match_sources="thread.name")], {"threadName": "main"}, "thread-only identity target is not enough to verify a unique process"),
            ([row(target_match_sources="thread.name")], None, "identity candidate has no process-level target match source"),
        ):
            with self.subTest(warning=warning):
                resolution = self.resolve(rows, target)
                self.assertEqual(resolution["status"], "ambiguous")
                self.assertIn(warning, resolution["warnings"])

    def test_scores_and_missing_rows(self) -> None:
        self.assertEqual(self.resolve([])["status"], "not_found")
        self.assertEqual(self.resolve([row(confidence_score=0)])["status"], "not_found")
        self.assertEqual(self.resolve([row(confidence_score=79)])["status"], "ambiguous")
        exact = self.resolve([row(confidence_score=50, identity_status="probable", target_match_sources="upid")], {"upid": 42})
        self.assertEqual(exact["status"], "verified")

    def test_a_failed_resolver_is_unresolved(self) -> None:
        resolution = self.resolve([], success=False)
        self.assertEqual((resolution["status"], resolution["resolverError"]), ("unresolved", "boom"))

    def test_a_pid_must_name_exactly_one_upid(self) -> None:
        for count, status in ((0, "not_found"), (2, "ambiguous")):
            resolution = self.resolve([row()], {"pid": 4242}, pid=(count, 42))
            self.assertEqual(resolution["status"], status)
            self.assertIn(f"PID 4242 maps to {count} UPIDs", resolution["warnings"][0])
        resolution = self.resolve([row(target_match_sources="upid")], {"pid": 4242}, pid=(1, 42))
        self.assertEqual(resolution["status"], "verified")
        self.assertIn("process.pid_unique_upid", resolution["evidenceSources"])

    def test_the_gate_caches_resolutions_but_not_failures(self) -> None:
        resolver = mock.Mock(return_value=(True, [row()], None))
        gate = identity.IdentityGate(resolver, mock.Mock())
        config = skill(identity={"policy": "verify_if_present"})
        gate.apply(config, {"package": "com.example"}, {})
        gate.apply(config, {"package": "com.example"}, {})
        self.assertEqual(resolver.call_count, 1)
        failing = mock.Mock(return_value=(False, [], "boom"))
        gate = identity.IdentityGate(failing, mock.Mock())
        gate.apply(config, {"package": "com.example"}, {})
        gate.apply(config, {"package": "com.example"}, {})
        self.assertEqual(failing.call_count, 2)


class RunnerGateIntegrationTest(unittest.TestCase):
    """The gate inside SkillRunner, with SmartPerfetto's handling of consumed selectors."""

    def setUp(self) -> None:
        import sys

        load_skill_script("perfetto_skill")
        from runtime.executor import SkillRunner

        self.runner_type = SkillRunner
        self.skill = {
            "id": "blocking", "type": "atomic", "runtime_status": "executable", "query_id": "blocking/root",
            "identity": {"policy": "required", "scope": "process", "aliases": ["process_name", "package"],
                         "rewriteTo": "recommended_process_name_param", "minConfidence": 50},
            "inputs": [{"name": "process_name", "type": "string", "required": True}],
        }

    def run_with(self, skills, skill_id, params, inherited=None):
        calls = []

        def query(query_id, **kwargs):
            calls.append(dict(kwargs["params"]))
            return [{"value": 1}]

        gate = identity.IdentityGate(
            lambda _params: (True, [row(process_name="com.real", recommended_process_name_param="com.real")], None),
            mock.Mock(),
        )
        runner = self.runner_type({"skills": skills}, query, identity_gate=gate)
        return runner.run(skill_id, params, _inherited=inherited), calls

    def test_a_default_alias_outside_the_skill_aliases_is_consumed_not_refused(self) -> None:
        result, calls = self.run_with({"blocking": self.skill}, "blocking", {"processName": "com.example"})
        self.assertTrue(result["success"], result)
        self.assertEqual(calls[0]["process_name"], "com.real")
        self.assertNotIn("processName", calls[0])

    def test_a_required_name_can_come_from_an_inherited_target(self) -> None:
        # As in SmartPerfetto, a call without its own selector targets the
        # process an inherited alias names, and the gate fills the input.
        result, calls = self.run_with(
            {"blocking": self.skill}, "blocking", {}, inherited={"package": "com.example"},
        )
        self.assertTrue(result["success"], result)
        self.assertEqual(calls[0]["process_name"], "com.real")


if __name__ == "__main__":
    unittest.main()
