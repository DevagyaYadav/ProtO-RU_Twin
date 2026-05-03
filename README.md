# ProtO-RU Single-Machine Setup with USRP B210

Working from-source deployment of ProtO-RU (O-RAN Split-7.2 Radio Unit) on a single Ubuntu machine with a USRP B210 SDR over a virtual ethernet loopback.

**Status:** ✅ Working — 92% RX_ON_TIME at full TDD line rate (~45,000 OFH packets/sec).

## Hardware

- Intel Xeon W-2133 (6c/12t @ 3.6 GHz), 31 GB RAM
- USRP B210 (FW 8.0, FPGA 16.0, USB3)
- Ubuntu 24.04.4 LTS, kernel 6.8.0-111-lowlatency

## Software

- srsRAN 24.10 (commit 9d5dd742a7), patched
- ProtO-RU (NUS-CIR fork of srsRAN 24.10)
- Open5GS 2.7.7
- UHD 4.6.0
- linuxptp 4.0

## Repository layout

- `configs/` — gNB and ProtO-RU YAML configurations (active + working backups)
- `evidence/` — runtime logs and config snapshots
- `ptp/` — software PTP grandmaster config for loopback
- `patches/` — source patches applied to upstream srsRAN

## Configuration highlights

- TDD n78, 20 MHz, 2x2 MIMO, 30 kHz SCS
- PLMN 999/70 (Open5GS default)
- BFP-9 IQ compression
- veth pair (`veth_du` ↔ `veth_ru`) as fronthaul substitute, MTU 9000
- PRACH config index 159 (short B4)

## Key tuning values

| Param | Value | Why |
|---|---|---|
| `T1a_max_up` (DU) | 2490 µs | gNB DL UP transmission window upper bound |
| `T2a_max_up` (RU) | 2600 µs | Tuned from 2454 to cover gNB's T1a_max_up |
| `T2a_min_up` (RU) | 2050 µs | Symmetric window adjustment |

## Two key fixes that unlocked end-to-end OFH

1. **PLMN mismatch:** srsRAN sample uses 001/01, Open5GS uses 999/70 → caused silent NGSetupFailure → gNB never started OFH transmission.
2. **T2a_max_up window misalignment:** RU's reception window was 36 µs narrower than what DU sends → all packets classified as `RX_EARLY`.

## Reproduce

See `docs/` for setup details (when added). Build from upstream:

```bash
git clone https://github.com/srsran/srsRAN_Project.git
cd srsRAN_Project && git checkout release_24_10
# Apply patches/srsran_t1a_range_extension.patch
mkdir build && cd build && cmake .. && make -j$(nproc) gnb

git clone https://github.com/NUS-CIR/ProtO-RU.git
cd ProtO-RU && mkdir build && cd build
cmake .. && cd apps/examples/ofh && make -j$(nproc)
```

## Credit

- ProtO-RU technical report: [arXiv:2512.02398](https://arxiv.org/abs/2512.02398) (Zhou et al., 2025)
- ProtO-RU repo: https://github.com/NUS-CIR/ProtO-RU
- srsRAN: https://github.com/srsran/srsRAN_Project
