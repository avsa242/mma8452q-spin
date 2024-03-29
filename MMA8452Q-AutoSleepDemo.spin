{
    --------------------------------------------
    Filename: MMA8452Q-AutoSleepDemo.spin
    Author: Jesse Burt
    Description: Demo of the MMA8452Q driver
        Auto-sleep functionality
    Copyright (c) 2022
    Started Nov 6, 2021
    Updated Nov 5, 2022
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    LED         = cfg#LED1
    SER_BAUD    = 115_200

    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_FREQ    = 400_000                       ' max is 400_000
    ADDR_BITS   = 0                             ' 0, 1

    INT1        = 24                            ' MMA8452Q INT1 pin
' --

    DAT_X_COL   = 20
    DAT_Y_COL   = DAT_X_COL + 15
    DAT_Z_COL   = DAT_Y_COL + 15

OBJ

    cfg     : "boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    sensor  : "sensor.accel.3dof.mma8452q"
    core    : "core.con.mma8452q"

VAR

    long _isr_stack[50]                         ' stack for ISR core
    long _intflag                               ' interrupt flag

PUB main{} | intsource, temp, sysmod

    setup{}
    sensor.preset_active{}                      ' default settings, but enable
                                                ' sensor power, and set
                                                ' scale factors

    sensor.auto_sleep_ena(true)                 ' enable auto-sleep
    sensor.accel_sleep_pwr_mode(sensor#LOPWR)   ' lo-power mode when sleeping
    sensor.accel_pwr_mode(sensor#HIGHRES)       ' high-res mode when awake
    sensor.trans_axis_ena(%011)                 ' transient detection on X, Y
    sensor.trans_thresh(0_252000)               ' set thresh to 0.252g (0..8g)
    sensor.trans_set_cnt(0)                     ' reset counter
    sensor.inact_set_time(5_120)                ' inactivity timeout ~5sec
    sensor.inact_int(sensor#WAKE_TRANS)         ' wake on transient accel
    sensor.accel_int_mask(sensor#INT_AUTOSLPWAKE | sensor#INT_TRANS)
    sensor.accel_int_routing(sensor#INT_AUTOSLPWAKE | sensor#INT_TRANS)
    sensor.accel_data_rate(100)                 ' 100Hz ODR when active
    sensor.auto_sleep_data_rate(6)              ' 6Hz ODR when sleeping
    dira[LED] := 1

    ' The demo continuously displays the current accelerometer data.
    ' When the sensor goes to sleep after approx. 5 seconds, the change
    '   in data rate is visible as a slowed update of the display.
    ' To wake the sensor, shake it along the X and/or Y axes
    '   by at least 0.252g's.
    ' When the sensor is awake, the LED should be on.
    ' When the sensor goes to sleep, it should turn off.
    repeat
        ser.pos_xy(0, 3)
        show_accel_data{}                       ' show accel data
        if (_intflag)                           ' interrupt triggered
            intsource := sensor.accel_int{}
            if (intsource & sensor#INT_TRANS)   ' transient acceleration event
                temp := sensor.trans_interrupt{}' clear the trans. interrupt
            if (intsource & sensor#INT_AUTOSLPWAKE)
                sysmod := sensor.sys_mode{}
                if (sysmod & sensor#SLEEP)      ' op. mode is sleep,
                    outa[LED] := 0              '   so turn LED off
                elseif (sysmod & sensor#ACTIVE) ' else active,
                    outa[LED] := 1              '   turn it on

        if (ser.rx_check{} == "c")              ' press the 'c' key in the demo
            cal_accel{}                         ' to calibrate sensor offsets

PRI cog_isr{}
' Interrupt service routine
    dira[INT1] := 0                             ' INT1 as input
    repeat
        waitpne(|< INT1, |< INT1, 0)            ' wait for INT1 (active low)
        _intflag := 1                           '   set flag
        waitpeq(|< INT1, |< INT1, 0)            ' now wait for it to clear
        _intflag := 0                           '   clear flag

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if sensor.startx(SCL_PIN, SDA_PIN, I2C_FREQ, ADDR_BITS)
        ser.strln(string("MMA8452Q driver started (I2C)"))
    else
        ser.strln(string("MMA8452Q driver failed to start - halting"))
        repeat

    cognew(cog_isr{}, @_isr_stack)                    ' start ISR in another core

#include "acceldemo.common.spinh"

DAT
{
Copyright 2022 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

