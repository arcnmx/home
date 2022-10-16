all: s31-000 s31-001 s31-002 s31-003 s31-004

s31-000: .esphome/build/s31-000/.pioenvs/s31-000/firmware.elf
s31-001: .esphome/build/s31-001/.pioenvs/s31-001/firmware.elf
s31-002: .esphome/build/s31-002/.pioenvs/s31-002/firmware.elf
s31-003: .esphome/build/s31-003/.pioenvs/s31-003/firmware.elf
s31-004: .esphome/build/s31-004/.pioenvs/s31-004/firmware.elf

.esphome/build/s31-000/.pioenvs/s31-000/firmware.elf: s31-000.yaml s31.yaml
	esphome compile s31-000.yaml

.esphome/build/s31-001/.pioenvs/s31-001/firmware.elf: s31-001.yaml s31.yaml
	esphome compile s31-001.yaml

.esphome/build/s31-002/.pioenvs/s31-002/firmware.elf: s31-002.yaml s31.yaml
	esphome compile s31-002.yaml

.esphome/build/s31-003/.pioenvs/s31-003/firmware.elf: s31-003.yaml s31.yaml
	esphome compile s31-003.yaml

.esphome/build/s31-004/.pioenvs/s31-004/firmware.elf: s31-004.yaml s31.yaml
	esphome compile s31-004.yaml
