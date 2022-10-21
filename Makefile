all: s31-000 s31-001 s31-002 s31-003 s31-004 swb1 fornuftig-001 outdoor bedroom

clean:
	rm -r ./build/

DEPS_GENERIC :=
DEPS_ESP8266 := esp8266-generic.yaml $(DEPS_GENERIC)
DEPS_ESP8266_D1 := esp8266-d1-mini.yaml $(DEPS_ESP8266)
DEPS_ESP8266_1M := esp8266-esp01_1m.yaml $(DEPS_ESP8266)
DEPS_S31 := s31.yaml $(DEPS_ESP8266_1M)
DEPS_FORNUFTIG := fornuftig.yaml $(DEPS_ESP8266_D1)
DEPS_FRIEND := $(DEPS_ESP8266_D1) esp8266-i2c.yaml esp8266-uart.yaml

s31-000: build/s31-000/firmware.elf
s31-001: build/s31-001/firmware.elf
s31-002: build/s31-002/firmware.elf
s31-003: build/s31-003/firmware.elf
s31-004: build/s31-004/firmware.elf
swb1: build/swb1/firmware.elf
fornuftig-001: build/fornuftig-001/firmware.elf
outdoor: build/outdoor/firmware.elf
bedroom: build/bedroom/firmware.elf

build/%/firmware.elf: %.yaml
	esphome compile $<
	cp -a build/$(patsubst %.yaml,%,$<)/.pioenvs/$(patsubst %.yaml,%,$<)/firmware.elf $@

build/s31-000/firmware.elf: $(DEPS_S31)
build/s31-001/firmware.elf: $(DEPS_S31)
build/s31-002/firmware.elf: $(DEPS_S31)
build/s31-003/firmware.elf: $(DEPS_S31)
build/swb1/firmware.elf: $(DEPS_ESP8266_1M)
build/fornuftig-001/firmware.elf: $(DEPS_FORNUFTIG)
build/outdoor/firmware.elf: $(DEPS_FRIEND) dht22.yaml ccs811.yaml
build/bedroom/firmware.elf: $(DEPS_FRIEND) dht22.yaml ccs811.yaml pms5003.yaml
