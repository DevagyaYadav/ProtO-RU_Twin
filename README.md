# TWiN-IITH-ProtORU

## Setup and Deployment of ProtO-RU: A Software-Based O-RAN Split-7.2 Radio Unit

**Student:** Devagya Yadav (CS25MTECH12003)  
**Course:** TWiN, IIT Hyderabad  
**GitHub:** https://github.com/DevagyaYadav/ProtO-RU_Twin

---

## Project Overview

This project reproduces and validates [ProtO-RU](https://github.com/NUS-CIR/ProtO-RU) (Zhou et al., arXiv:2512.02398) — an open-source software-defined O-RAN Split-7.2 Radio Unit — on a **single physical machine** with a **USRP B210** SDR, deviating from the paper's two-machine 10 GbE testbed.

The full stack (Open5GS 5G core + srsRAN 24.10 gNB + ProtO-RU ru_emulator) is built from source on Ubuntu 24.04. A Linux veth pair replaces the physical 10 GbE fronthaul, and software PTP provides loopback time synchronisation.

**Result achieved:** 92.4% RX_ON_TIME at ~45,000 OFH packets/sec with zero protocol errors.

Two non-obvious integration issues were diagnosed and fixed that are not documented in the paper:
1. **PLMN mismatch** between srsRAN (001/01) and Open5GS (999/70) causing silent NGSetupFailure and zero OFH transmission
2. **OFH timing window misalignment** — T2a_max_up (2454 µs) narrower than T1a_max_up (2490 µs), causing 87% of packets to be classified as RX_EARLY

---

## Repository Structure

```
TWiN-IITH-ProtORU/
├── configs/                  Active and backup configuration files
│   ├── gnb.yml               srsRAN gNB config (PLMN 99970, T1a tuned)
│   ├── ru_emu.yml            ProtO-RU config (T2a_max_up tuned to 2600 µs)
│   ├── gnb.yml.working       Backup of verified working gNB config
│   └── ru_emu.yml.working    Backup of verified working ProtO-RU config
├── docs/                     Report, slides, and diagrams
│   ├── ProtO-RU_Twin_Report.pdf
│   └── ProtO-RU_Twin_Slides.pptx
├── patches/                  Source patches applied to upstream
│   └── srsran_t1a_range_extension.patch
├── ptp/                      Time synchronisation config
│   └── ptp4l_loopback.conf
├── scripts/                  Setup and utility scripts
│   ├── start_stack.sh        Pre-flight check and startup guide
│   └── cleanup_cgroups.sh    Clean stale srs cgroups before launch
├── results/                  Captured runtime logs and evidence
│   ├── gnb_internal_*.log    gNB internal debug log
│   └── gnb_stdout_*.log      gNB stdout capture
├── demo/                     Demo video and description
│   └── README.md
├── .gitignore
└── README.md                 This file
```

---

## Hardware Requirements

| Component | Spec used | Minimum |
|---|---|---|
| CPU | Intel Xeon W-2133 (6c/12t, 3.6 GHz) | 4 cores |
| RAM | 32 GB | 8 GB
| SDR | USRP B210 (FW 8.0, FPGA 16.0) | USRP B200/B210 |
| USB | USB 3.0 port | USB 3.0 |
| OS | Ubuntu 24.04.4 LTS | Ubuntu 22.04+ |
| Kernel | 6.8.0-111-lowlatency | Generic also works |

---

## Software Dependencies

```bash
# System packages
sudo apt update
sudo apt install -y cmake build-essential git python3 python3-pip \
    libuhd-dev uhd-host libfftw3-dev libmbedtls-dev libboost-all-dev \
    libconfig++-dev libsctp-dev libssl-dev linuxptp

# Download UHD FPGA images
sudo uhd_images_downloader

# Open5GS (via PPA)
sudo add-apt-repository ppa:open5gs/latest
sudo apt update
sudo apt install -y open5gs open5gs-dbctl

# Optional: lowlatency kernel
sudo apt install -y linux-lowlatency
```

---

## Setup Instructions

### 1. Clone required repositories

```bash
mkdir -p ~/oran-stack && cd ~/oran-stack

# srsRAN Project (gNB/DU)
git clone https://github.com/srsran/srsRAN_Project.git srsRAN
cd srsRAN && git checkout release_24_10 && cd ..

# ProtO-RU
git clone https://github.com/NUS-CIR/ProtO-RU.git
```

### 2. Apply the srsRAN T1a patch

```bash
cd ~/oran-stack/srsRAN
git apply ~/path/to/patches/srsran_t1a_range_extension.patch
```

This raises the CLI::Range upper bound for T1a parameters from 1960 to 5000 µs, which is required for ProtO-RU's software pipeline timing.

### 3. Build srsRAN gNB

```bash
cd ~/oran-stack/srsRAN
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc) gnb
# Binary: ~/oran-stack/srsRAN/build/apps/gnb/gnb
```

### 4. Build ProtO-RU

```bash
cd ~/oran-stack/ProtO-RU
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_ZEROMQ=OFF ..
cd apps/examples/ofh && make -j$(nproc)
# Binary: ~/oran-stack/ProtO-RU/build/apps/examples/ofh/ru_emulator
```

Note: `-DENABLE_ZEROMQ=OFF` is required due to an upstream build error in `radio_session_zmq_impl`.

### 5. Configure Open5GS

```bash
# Verify PLMN is 999/70 in AMF config (this is the default)
sudo grep -E "mcc:|mnc:" /etc/open5gs/amf.yaml | head -6
# Should show mcc: 999 and mnc: 70

# Add test subscriber
sudo open5gs-dbctl add 999700000000001 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA
```

### 6. Set up software PTP

```bash
sudo cp ptp/ptp4l_loopback.conf /etc/ptp4l_loopback.conf
```

### 7. Set up veth fronthaul pair

```bash
sudo ip link add veth_du type veth peer name veth_ru
sudo ip link set veth_du up && sudo ip link set veth_ru up
sudo ip link set veth_du mtu 9000 && sudo ip link set veth_ru mtu 9000

# Verify MACs match config values
echo "veth_du: $(cat /sys/class/net/veth_du/address)"
echo "veth_ru: $(cat /sys/class/net/veth_ru/address)"
# Expected: 2e:c7:77:9e:d0:96 and c2:17:5f:8f:dc:90
# If different, update mac_addr fields in configs/gnb.yml and configs/ru_emu.yml
```

---

## How to Run

Run each command in a **separate terminal**. Order matters.

### Terminal 1 — Start ProtO-RU

```bash
sudo ptp4l -i lo -f /etc/ptp4l_loopback.conf -m &
sleep 5
sudo phc2sys -s CLOCK_REALTIME -O 0 -m &

cd ~/oran-stack/ProtO-RU/build/apps/examples/ofh
sudo ./ru_emulator -c ~/path/to/configs/ru_emu.yml 2>&1 | tee /tmp/ru_run.log
```

Wait for the statistics table to appear (all zeros initially).

### Terminal 2 — Start gNB

```bash
cd ~/oran-stack/srsRAN/build
sudo ./apps/gnb/gnb -c ~/path/to/configs/gnb.yml 2>&1 | tee /tmp/gnb_run.log
```

Wait for `==== gNB started ===` and `N2: Connection to AMF... completed`.

### Expected output in Terminal 1

Within ~30 seconds of gNB starting, the ProtO-RU stats table should show:

```
| TIME     | RX_TOTAL | RX_ON_TIME | RX_EARLY | RX_LATE | RX_SEQ_ERR | TX_TOTAL |
| HH:MM:SS |  ~45000  |  ~41580    |    0     |   ~30   |    0/0     |  ~2200   |
```

---

## Experiment Reproduction Steps

### Reproduce the key result (92.4% RX_ON_TIME)

1. Complete all setup steps above
2. Start ProtO-RU (Terminal 1) and gNB (Terminal 2)
3. Wait 60 seconds for the system to reach steady state
4. Observe the ProtO-RU statistics table
5. Run the metric capture script:

```bash
bash experiments/capture_metrics.sh
```

Logs are saved to `results/` with a timestamp.


## Results Summary

| Metric | Value |
|---|---|
| OFH packet rate (RX_TOTAL) | ~45,000 packets/sec |
| RX_ON_TIME | ~41,580 packets/sec (92.4%) |
| RX_EARLY | 0 |
| RX_LATE | ~30 packets/sec (<0.1%) |
| RX_SEQ_ERR | 0 |
| RX_CORRUPT | 0 |
| TX_TOTAL (RU → DU) | ~2,200 packets/sec |
| Cell scheduler latency | 5 µs mean |
| Scheduler errors | 0 |

Cell configuration: TDD n78, 3420.48 MHz, 20 MHz BW, 2x2 MIMO, 30 kHz SCS, BFP-9 compression.

## Limitations

- **Core pinning disabled:** `expert_execution` is commented out in both configs due to stale cgroups from a prior Docker setup. This limits RX_ON_TIME to ~92% vs 99%+ in the paper.
- **UE attach not completed:** A second B210 was configured with srsue but never found the cell, likely due to lack of a shared 10 MHz clock reference between the two B210s.
- **No Split-8 comparison:** Planned but not completed within the project timeline.

---

## LLM Usage Disclosure

> *LLM-assisted code and documentation for TWiN Project — CS25MTECH12003*

**Models used:**
- Anthropic Claude (Claude Sonnet 4.6) — log analysis, config debugging, documentation
- OpenAI ChatGPT (GPT-5) — cross-checking, alternative phrasings

**How LLM output was validated:**
- All commands suggested by LLMs were reviewed before execution
- Config changes were verified by re-running the stack and observing metric changes
- Technical claims were cross-checked against the ProtO-RU paper and srsRAN source
- Build output was verified after each patch
- Creating Readme
**Sample prompts used:**
- *"Here are the last 80 lines of /tmp/gnb.log. The gNB initialises OFH and connects to AMF, but tcpdump shows zero eCPRI frames on veth_du. What should I check?"*
- *"ProtO-RU shows RX_EARLY ~39,000. The gNB has t1a_max_up: 2490 and the RU has t2a_max_up: 2454. Is this the misalignment causing it?"*
- *"srsRAN rejects t1a_max_cp_dl: 2635 saying value must be in [0, 1960]. Where is this defined in source?"*

---

## References

1. Z. Zhou et al. "ProtO-RU: An O-RAN Split-7.2 Radio Unit using SDRs." arXiv:2512.02398, 2025.
2. ProtO-RU repository: https://github.com/NUS-CIR/ProtO-RU
3. srsRAN Project: https://github.com/srsran/srsRAN_Project
4. Open5GS: https://open5gs.org/open5gs/docs/
5. srsRAN_4G (srsue): https://github.com/srsran/srsRAN_4G
6. O-RAN Alliance WG4 Fronthaul Spec: ORAN-WG4.CUS.0-v10.00, 2022