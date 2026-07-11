# Thermal and power knowledge

Use the generated [thermal guide](../generated/knowledge/knowledge-thermal-throttling.template.md)
and measured rail, Wattson, battery, wakelock, CPU/GPU, screen, doze, and sensor
signals that are actually present.

Separate four questions: workload demand, measured energy/power, policy
response, and thermal limit. Low frequency is not thermal throttling without a
temperature, cooling, cap, or policy signal. Temporal overlap with a rail or
battery counter is not process attribution. Wattson and rail models have device
and capture prerequisites; state their coverage before quoting energy.

For background drain, bind wakelocks, jobs, modem/network, screen state, and CPU
work to the same interval. For thermal causality, show rising temperature or
cooling state, an effective frequency/cap response, and symptom impact while
considering workload changes.
