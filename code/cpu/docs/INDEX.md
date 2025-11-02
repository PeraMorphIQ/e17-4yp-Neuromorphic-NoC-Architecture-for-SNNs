# Documentation Index

This directory contains all documentation for the Neuromorphic NoC Architecture with RISC-V CPUs.

## Quick Start

- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick reference guide for common tasks and commands

## System Documentation

### Architecture & Design

- **[SYSTEM_TOP_README.md](SYSTEM_TOP_README.md)** - Complete system architecture without CPUs (2×2 mesh NoC with neuron banks)
- **[SYSTEM_WITH_CPU_README.md](SYSTEM_WITH_CPU_README.md)** - CPU-integrated system architecture (RV32IMF CPUs per node)
- **[NOC_README.md](NOC_README.md)** - Network-on-Chip architecture and router details
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Summary of all implemented features

### Integration & Setup

- **[COMPLETE_INTEGRATION_GUIDE.md](COMPLETE_INTEGRATION_GUIDE.md)** - Step-by-step integration workflow (build, test, synthesis)
- **[INTEGRATION_STATUS.md](INTEGRATION_STATUS.md)** - Current integration status and deliverables
- **[SYSTEM_CREATION_SUMMARY.md](SYSTEM_CREATION_SUMMARY.md)** - Summary of system creation process

### Testing

- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Comprehensive testing guide for all modules
- **[TEST_EXECUTION_SUMMARY.md](TEST_EXECUTION_SUMMARY.md)** - Latest test execution results and status

## Document Overview

| Document                      | Purpose                                     | Audience                |
| ----------------------------- | ------------------------------------------- | ----------------------- |
| QUICK_REFERENCE.md            | Fast lookup for commands and workflows      | All users               |
| SYSTEM_TOP_README.md          | Working system architecture (NoC + Neurons) | Developers, Testers     |
| SYSTEM_WITH_CPU_README.md     | CPU integration design                      | Developers              |
| NOC_README.md                 | Network-on-Chip internals                   | Hardware designers      |
| COMPLETE_INTEGRATION_GUIDE.md | Build and test instructions                 | Developers, CI/CD       |
| TESTING_GUIDE.md              | How to run tests                            | Testers, QA             |
| TEST_EXECUTION_SUMMARY.md     | Test results and metrics                    | Project managers, QA    |
| IMPLEMENTATION_SUMMARY.md     | Feature checklist                           | Project managers        |
| INTEGRATION_STATUS.md         | Current project status                      | All stakeholders        |
| SYSTEM_CREATION_SUMMARY.md    | Development history                         | Documentation reference |

## Getting Started

### For New Users:

1. Start with **QUICK_REFERENCE.md** for basic commands
2. Read **SYSTEM_TOP_README.md** to understand the working architecture
3. Follow **TESTING_GUIDE.md** to run validation tests

### For Developers:

1. Review **IMPLEMENTATION_SUMMARY.md** for feature overview
2. Study **COMPLETE_INTEGRATION_GUIDE.md** for build workflows
3. Check **INTEGRATION_STATUS.md** for current progress

### For Testers:

1. Follow **TESTING_GUIDE.md** for test procedures
2. Review **TEST_EXECUTION_SUMMARY.md** for latest results
3. Use **QUICK_REFERENCE.md** for command syntax

## Related Documentation

- **[../README.md](../README.md)** - Main CPU module README
- **[../programs/README.md](../programs/README.md)** - Assembly programming guide
- **[../../power/POWER_ANALYSIS_README.md](../../power/POWER_ANALYSIS_README.md)** - Power analysis documentation

## Current Status

✅ **Fully Functional:**

- 2×2 Mesh NoC with XY routing
- Network interfaces (AXI4-Lite to NoC)
- Neuron banks (IEEE 754 FPU)
- Instruction memory
- CPU standalone operation
- CPU + Neuron Bank integration

✅ **All Tests Passing:**

- System Top: 6/6 tests PASSED (100%)
- CPU + Neuron Bank Integration: PASSED

⏸️ **Pending:**

- Full 4-CPU system integration
- Assembly program execution on integrated system

---

_Last Updated: November 3, 2025_
