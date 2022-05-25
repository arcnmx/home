#!/usr/bin/env python

import sys
import time
import dbus
from types import SimpleNamespace

bus = dbus.SystemBus()
manager = dbus.Interface(bus.get_object('org.ofono', '/'), 'org.ofono.Manager')

def modem_vcm(modem):
    # this interface isn't available right away when connecting, so wait for it
    for limit in range(32):
        props = modem.modem().GetProperties()
        if 'org.ofono.VoiceCallManager' in props['Interfaces']:
            return dbus.Interface(modem.obj, 'org.ofono.VoiceCallManager')
        time.sleep(0.1)
    raise Exception('VoiceCallManager timeout')

def modems():
    global manager
    global bus
    for path, properties in manager.GetModems():
        obj = bus.get_object('org.ofono', path)
        this = SimpleNamespace(
            path = path,
            properties = properties,
            obj = obj,
            modem = lambda: dbus.Interface(obj, 'org.ofono.Modem'),
            vcm = lambda: modem_vcm(this),
            handsfree = lambda: dbus.Interface(obj, 'org.ofono.Handsfree'),
        )
        yield this

def calls(modem):
    global bus
    for limit in range(32):
        # even once interface is available, calls can take a moment to show up
        calls = modem.vcm().GetCalls()
        if len(calls) > 0:
            break
        time.sleep(0.1)
    for path, properties in calls:
        obj = bus.get_object('org.ofono', path)
        yield SimpleNamespace(
            path = path,
            properties = properties,
            obj = obj,
            vc = lambda: dbus.Interface(obj, 'org.ofono.VoiceCall'),
        )

def modempath():
    global manager
    modems = manager.GetModems()
    return modems[0][0]

def connect(modem):
    modem.modem().SetProperty('Powered', dbus.Boolean(1), timeout = 120)

def disconnect(modem):
    modem.modem().SetProperty('Powered', dbus.Boolean(0), timeout = 120)

def dtmf(modem, tone):
    modem.vcm().SetProperty('ToneDuration', 'long') # 'short' or 'long'
    modem.vcm().SendTones(tone)

def call(modem, number, hide_callerid = None):
    if hide_callerid == None:
        callerid = 'default'
    elif hide_callerid:
        callerid = 'enabled'
    else:
        callerid = 'disabled'
    modem.vcm().Dial(number, callerid)

def voice(modem):
    modem.handsfree().SetProperty('VoiceRecognition', dbus.Boolean(1))

def active_call(modem):
    for call in calls(modem):
        if call.properties['State'] == 'active':
            return call
    raise Exception('no active call found')

def incoming_call(modem):
    for call in calls(modem):
        if call.properties['State'] == 'incoming':
            return call
    raise Exception('no incoming call found')

command = sys.argv[1]

modem = next(modems())

if command == 'hangup':
    connect(modem)
    active_call(modem).vc().Hangup()
elif command == 'answer':
    connect(modem)
    incoming_call(modem).vc().Answer()
elif command == 'toggle-call':
    connect(modem)
    for call in calls(modem):
        if call.properties['State'] == 'incoming':
            call.vc().Answer()
            break
        elif call.properties['State'] == 'active':
            call.vc().Hangup()
            break
elif command == 'toggle-connect':
    if modem.properties['Powered']:
        disconnect(modem)
    else:
        connect(modem)
elif command == 'voice':
    connect(modem)
    voice(modem)
elif command == 'call':
    connect(modem)
    call(modem, sys.argv[2])
elif command == 'buzz':
    connect(modem)
    try:
        dtmf(modem, '9')
    except:
        pass # this fails even though it seems to work?
    time.sleep(0.5)
    dtmf(modem, '0')
elif command == 'connect':
    connect(modem)
elif command == 'disconnect':
    disconnect(modem)
else:
    raise Exception('command unknown')
