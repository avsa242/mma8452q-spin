{
    --------------------------------------------
    Filename: MMA8452Q-FreeFall-Demo.spin
    Author: Jesse Burt
    Description: Demo of the MMA8452Q driver
        Free-fall detection functionality
    Copyright (c) 2022
    Started Nov 7, 2021
    Updated Aug 18, 2022
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

    INT1        = 16
' --

    DAT_X_COL   = 20
    DAT_Y_COL   = DAT_X_COL + 15
    DAT_Z_COL   = DAT_Y_COL + 15

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    accel   : "sensor.accel.3dof.mma8452q"

VAR

    long _isr_stack[50]                         ' stack for ISR core
    long _intflag                               ' interrupt flag

PUB Main{} | intsource, temp

    setup{}
    accel.preset_freefall{}                     ' default settings, but enable
                                                ' sensors, set scale factors,
                                                ' and free-fall parameters
    ser.position(0, 5)
    ser.str(string("Sensor stable       "))

    ' The demo continuously displays the current accelerometer data.
    ' When the sensor detects free-fall, a message is displayed and
    '   is cleared after the user presses a key
    ' The preset for free-fall detection sets a free-fall threshold of
    '   0.315g's for a minimum time of 30ms. This can be tuned using
    '   accel.FreeFallThresh() and accel.FreeFallTime():
    accel.freefallthresh(0_315000)              ' 0.315g's
    accel.freefalltime(30_000)                  ' 30_000us/30ms
    repeat
        ser.position(0, 3)
        acceldata{}                             ' show accel data
        if _intflag                             ' interrupt triggered
            intsource := accel.interrupt{}
            if (intsource & accel#INT_FFALL)    ' free-fall event
                temp := accel.infreefall{}      ' clear the free-fall interrupt
            ser.position(0, 5)
            ser.strln(string("Sensor in free-fall!"))
            ser.str(string("Press any key to reset"))
            ser.charin{}
            ser.positionx(0)
            ser.clearline{}
            ser.position(0, 5)
            ser.str(string("Sensor stable       "))
            
        if ser.rxcheck{} == "c"                 ' press the 'c' key in the demo
            cal_accel{}                         ' to calibrate sensor offsets

PRI ISR{}
' Interrupt service routine
    dira[INT1] := 0                             ' INT1 as input
    repeat
        waitpne(|< INT1, |< INT1, 0)            ' wait for INT1 (active low)
        _intflag := 1                           '   set flag
        waitpeq(|< INT1, |< INT1, 0)            ' now wait for it to clear
        _intflag := 0                           '   clear flag

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if accel.startx(SCL_PIN, SDA_PIN, I2C_FREQ, ADDR_BITS)
        ser.strln(string("MMA8452Q driver started"))
    else
        ser.strln(string("MMA8452Q driver failed to start - halting"))
        repeat

    cognew(isr, @_isr_stack)                    ' start ISR in another core

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

