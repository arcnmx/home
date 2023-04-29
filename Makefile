all: s31-000 s31-001 s31-002 s31-003 s31-004 swb1-001 fornuftig-001 outdoor bedroom kitchen dirty kittylamp-001

secrets.yaml: secrets.sops.yaml
	sops -d $< > $@

clean:
	rm -r ./build/

DEPS_GENERIC := generic.yaml
DEPS_ESP8266 := esp8266-generic.yaml $(DEPS_GENERIC)
DEPS_ESP8266_D1 := esp8266-d1-mini.yaml $(DEPS_ESP8266)
DEPS_ESP8266_1M := esp8266-esp01_1m.yaml $(DEPS_ESP8266)
DEPS_ESP8266_I2C := esp8266-i2c.yaml
DEPS_ESP8266_UART := esp8266-uart.yaml
DEPS_ESP32 := esp32-generic.yaml $(DEPS_GENERIC)
DEPS_ESP32_WROOM32 := esp32-wroom32-devkitc-v4.yaml $(DEPS_ESP32)
DEPS_ESP32_I2C := esp32-i2c.yaml
DEPS_SWB1 := swb1.yaml $(DEPS_ESP8266_1M)
DEPS_S31 := s31.yaml $(DEPS_ESP8266_1M)
DEPS_FORNUFTIG := fornuftig.yaml $(DEPS_ESP8266_D1)
DEPS_SENSORFRIEND := sensorfriend.yaml $(DEPS_ESP8266_D1) $(DEPS_ESP8266_I2C) $(DEPS_ESP8266_UART)
DEPS_SENSORFRIEND32 := $(DEPS_ESP32_WROOM32)
DEPS_LED32 := led.yaml $(DEPS_ESP32_WROOM32) $(DEPS_ESP32_I2C)
DEPS_KITTYLAMP := kittylamp.yaml $(DEPS_ESP8266_D1)

s31-000: build/s31-000/firmware.elf
s31-001: build/s31-001/firmware.elf
s31-002: build/s31-002/firmware.elf
s31-003: build/s31-003/firmware.elf
s31-004: build/s31-004/firmware.elf
swb1-001: build/swb1-001/firmware.elf
fornuftig-001: build/fornuftig-001/firmware.elf
kittylamp-001: build/kittylamp-001/firmware.elf
outdoor: build/outdoor/firmware.elf
bedroom: build/bedroom/firmware.elf
kitchen: build/kitchen/firmware.elf
dirty: build/dirty/firmware.elf

build/%/firmware.elf: %.yaml
	esphome compile $<
	cp -a build/$(patsubst %.yaml,%,$<)/.pioenvs/$(patsubst %.yaml,%,$<)/firmware.elf $@

build/s31-000/firmware.elf: $(DEPS_S31)
build/s31-001/firmware.elf: $(DEPS_S31)
build/s31-002/firmware.elf: $(DEPS_S31)
build/s31-003/firmware.elf: $(DEPS_S31)
build/swb1-001/firmware.elf: $(DEPS_SWB1)
build/fornuftig-001/firmware.elf: $(DEPS_FORNUFTIG)
build/kittylamp-001/firmware.elf: $(DEPS_KITTYLAMP)
build/outdoor/firmware.elf: $(DEPS_SENSORFRIEND) dht22.yaml ccs811.yaml
build/bedroom/firmware.elf: $(DEPS_SENSORFRIEND) dht22.yaml scd41.yaml pms5003.yaml
build/kitchen/firmware.elf: $(DEPS_SENSORFRIEND) sen55.yaml scd41.yaml
build/dirty/firmware.elf: $(DEPS_SENSORFRIEND32) sen55.yaml

.PHONY: all clean
.DELETE_ON_ERROR:
