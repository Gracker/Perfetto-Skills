"""Authored Perfetto traces for framework lifecycle and JobScheduler events.

Public real traces predate these Android framework data sources, so the query
contracts are proven on small synthetic traces encoded here. They establish SQL
semantics only and never count as real-device coverage in the fixture manifest.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from tests.support import load_skill_script


BASE_NS = 1_000_000_000
MS = 1_000_000
SEQUENCE_ID = 7

TOP = 1002
SERVICE = 1009
LAST_ACTIVITY = 1014
CACHED_ACTIVITY = 1015
CACHED_EMPTY = 1018
NONEXISTENT = 1019
PERSISTENT = 1000

OOM_ACTIVITY = 1
OOM_UI_VISIBILITY = 9
OOM_STOP_SERVICE = 19
HOSTING_ACTIVITY = 1
TRIGGER_JOB = 4
EXIT_LOW_MEMORY = 3
EXIT_SUB_MEMORY_PRESSURE = 6

JOB_STARTED = 1
JOB_CANCELLED = 3
JOB_FINISHED = 4
STOP_SUCCESSFUL_FINISH = 10
PENDING_BACKGROUND_RESTRICTION = 3
PENDING_CHARGING = 5
PENDING_DEVICE_IDLE = 8
PENDING_QUOTA = 14


_common = load_skill_script("_common")
_int = _common._pb_uint


def _bytes(field: int, value: bytes | str) -> bytes:
    return _common._pb_bytes(field, value.encode("utf-8") if isinstance(value, str) else value)


def _optional_int(field: int, value: int | None) -> bytes:
    return b"" if value is None else _int(field, value)


@dataclass(frozen=True)
class Process:
    name: str
    pid: int
    uid: int


def at_ms(offset_ms: int) -> int:
    return BASE_NS + offset_ms * MS


def _identity(process: Process) -> bytes:
    return _int(1, process.uid) + _int(2, process.pid) + _bytes(3, process.name)


APP = Process("com.example.lifecycle", 4101, 10123)
SYNC = Process("com.example.lifecycle:sync", 4102, 10123)
SYSTEM = Process("system_server", 1500, 1000)
STATELESS = Process("com.example.stateless", 4103, 10124)
FRAMEWORK_TID = 1501
START_SEQ = 77


class _TraceWriter:
    def __init__(self, processes: tuple[Process, ...]) -> None:
        self.framework_track = (SEQUENCE_ID << 32) | FRAMEWORK_TID
        self.prints: list[bytes] = []
        self.packets: list[bytes] = []
        clocks = b"".join(
            _bytes(1, _int(1, clock) + _int(2, BASE_NS)) for clock in (1, 5, 6)
        )
        tree = b"".join(
            _bytes(1, _int(1, p.pid) + _int(2, 1) + _bytes(3, p.name) + _int(5, p.uid))
            for p in (*processes, SYSTEM)
        )
        tree += _bytes(2, _int(1, FRAMEWORK_TID) + _bytes(2, "framework") + _int(3, SYSTEM.pid))
        self._packet(None, _bytes(6, _bytes(1, clocks) + _int(2, 6)))
        self._packet(BASE_NS, _int(41, 1) + _bytes(2, tree))
        descriptor = _int(1, self.framework_track) + _bytes(
            4, _int(1, SYSTEM.pid) + _int(2, FRAMEWORK_TID) + _bytes(5, "framework")
        )
        self._packet(BASE_NS, _bytes(60, descriptor))

    def _packet(self, timestamp: int | None, body: bytes) -> None:
        stamped = b"" if timestamp is None else _int(8, timestamp)
        self.packets.append(_bytes(1, stamped + _int(10, SEQUENCE_ID) + body))

    def framework_instant(self, offset_ms: int, extension_field: int, event: bytes) -> None:
        body = _int(9, 3) + _int(11, self.framework_track) + _bytes(23, "event")
        self._packet(at_ms(offset_ms), _bytes(11, body + _bytes(extension_field, event)))

    def job_scheduler_slice(self, offset_ms: int, event: bytes) -> None:
        begin = (
            _int(9, 1)
            + _int(11, self.framework_track)
            + _bytes(22, "jobscheduler")
            + _bytes(23, "JobSchedulerStateEvent")
            + _bytes(2006, event)
        )
        self._packet(at_ms(offset_ms), _bytes(11, begin))
        self._packet(at_ms(offset_ms) + MS, _bytes(11, _int(9, 2) + _int(11, self.framework_track)))

    def snapshot(self, offset_ms: int, records: tuple[tuple[Process, int], ...]) -> None:
        payload = b"".join(
            _bytes(1, _int(1, p.pid) + _int(2, p.uid) + _int(3, state) + _bytes(6, p.name))
            for p, state in records
        )
        self._packet(at_ms(offset_ms), _bytes(1002, payload))

    def intern_job_name(self, offset_ms: int, iid: int, name: str) -> None:
        self._packet(at_ms(offset_ms), _bytes(12, _bytes(44, _int(1, iid) + _bytes(2, name))))

    def packages_list(self, processes: tuple[Process, ...]) -> None:
        packages = b"".join(_bytes(1, _bytes(1, p.name) + _int(2, p.uid)) for p in processes)
        self._packet(BASE_NS, _bytes(47, packages))

    def atrace_print(self, offset_ms: int, buf: str) -> None:
        self.prints.append(
            _bytes(2, _int(1, at_ms(offset_ms)) + _int(2, FRAMEWORK_TID) + _bytes(3, _bytes(2, buf)))
        )

    def finish(self, path: Path) -> Path:
        if self.prints:
            self._packet(BASE_NS, _bytes(1, _int(1, 0) + b"".join(self.prints)))
        path.write_bytes(b"".join(self.packets))
        return path




def _state_change(
    target: Process,
    previous: int,
    current: int,
    reason: int | None,
    sequence: int,
) -> bytes:
    return (
        _int(1, target.uid)
        + _int(2, target.pid)
        + _int(3, previous)
        + _int(4, current)
        + _optional_int(9, reason)
        + _int(10, sequence)
    )


def write_process_state_trace(path: Path) -> Path:
    """App lifecycle: offsets are milliseconds after ``BASE_NS``."""

    trace = _TraceWriter((APP, SYNC, STATELESS))
    trace.framework_instant(
        20,
        2010,
        _identity(APP)
        + _int(4, 0)
        + _int(5, 40)
        + _bytes(6, f"{{{APP.name}/.MainActivity}}")
        + _int(7, HOSTING_ACTIVITY)
        + _int(8, TRIGGER_JOB)
        + _int(10, START_SEQ),
    )
    trace.framework_instant(60, 2012, _state_change(APP, NONEXISTENT, TOP, None, 0))
    trace.framework_instant(160, 2012, _state_change(APP, TOP, LAST_ACTIVITY, OOM_ACTIVITY, 1))
    trace.framework_instant(
        460, 2012, _state_change(APP, LAST_ACTIVITY, CACHED_ACTIVITY, OOM_UI_VISIBILITY, 2)
    )
    trace.framework_instant(
        520, 2012, _state_change(SYNC, SERVICE, CACHED_EMPTY, OOM_STOP_SERVICE, 3)
    )
    trace.framework_instant(
        760, 2013, _identity(APP) + _int(4, START_SEQ)
    )
    trace.framework_instant(
        820,
        2011,
        _identity(APP)
        + _int(4, EXIT_LOW_MEMORY)
        + _int(5, EXIT_SUB_MEMORY_PRESSURE)
        + _int(9, START_SEQ),
    )
    trace.snapshot(980, ((SYNC, CACHED_EMPTY), (SYSTEM, PERSISTENT)))
    return trace.finish(path)


JOB_APP = Process("com.example.jobs", 5101, 10234)
JOB_PEER = Process("com.example.peer", 5102, 10235)
JOB_IDLE = Process("com.example.idle", 5103, 10236)


def _job_event(
    owner: Process,
    job_id: int,
    state: int,
    iid: int,
    reasons: tuple[int, ...] = (),
    durations_ms: tuple[int, ...] = (),
    stop_reason: int | None = None,
) -> bytes:
    event = _int(1, job_id) + _int(2, owner.uid) + _int(4, state)
    event += _optional_int(18, stop_reason) + _int(21, iid)
    event += b"".join(_int(22, reason) for reason in reasons)
    event += b"".join(_int(23, value) for value in durations_ms)
    return event


def write_job_scheduler_trace(path: Path) -> Path:
    """Completed, cancelled, unfinished and out-of-window jobs for one package."""

    trace = _TraceWriter((JOB_APP, JOB_PEER, JOB_IDLE))
    trace.packages_list((JOB_APP, JOB_PEER, JOB_IDLE))
    jobs = ((JOB_APP, 101), (JOB_APP, 102), (JOB_PEER, 201), (JOB_APP, 103), (JOB_APP, 104), (JOB_APP, 105))
    interned = {job_id: iid for iid, (_, job_id) in enumerate(jobs, start=1)}
    owners = {job_id: owner for owner, job_id in jobs}
    for owner, job_id in jobs:
        trace.intern_job_name(1, interned[job_id], f"{owner.name}/.SyncJob#{job_id}")

    def record(offset_ms: int, job_id: int, state: int, **details: object) -> None:
        trace.job_scheduler_slice(offset_ms, _job_event(owners[job_id], job_id, state, interned[job_id], **details))

    completed = (
        (100, 200, 101, (PENDING_CHARGING,), (1500,)),
        (300, 400, 102, (PENDING_CHARGING, PENDING_QUOTA), (500,)),
        (500, 600, 201, (PENDING_CHARGING,), (9000,)),
        (900, 950, 105, (PENDING_QUOTA,), (9999,)),
    )
    for started_ms, finished_ms, job_id, reasons, durations_ms in completed:
        record(started_ms, job_id, JOB_STARTED, reasons=reasons, durations_ms=durations_ms)
        record(finished_ms, job_id, JOB_FINISHED, stop_reason=STOP_SUCCESSFUL_FINISH)
    record(650, 103, JOB_CANCELLED, reasons=(PENDING_BACKGROUND_RESTRICTION,), durations_ms=(3000,))
    record(700, 104, JOB_STARTED, reasons=(PENDING_DEVICE_IDLE,), durations_ms=(7000,))

    job_slice = f"scheduled job #12#<{JOB_APP.uid}>{JOB_APP.name}/.SyntheticJob#"
    trace.atrace_print(150, f"G|{SYSTEM.pid}|JobScheduler|{job_slice}|12")
    trace.atrace_print(180, f"H|{SYSTEM.pid}|JobScheduler|{job_slice}|12")
    return trace.finish(path)
