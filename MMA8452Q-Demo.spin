{
    --------------------------------------------
    Filename: MMA8452Q-Demo.spin
    Author: Jesse Burt
    Description: MMA8452Q driver demo
        * 3DoF data output
    Copyright (c) 2022
    Started Aug 12, 2017
    Updated Jul 21, 2022
    See end of file for terms of use.
    --------------------------------------------

    Build-time symbols supported by driver:
        -DMMA8452Q_I2C (default if none specified)
        -DMMA8452Q_I2C_BC
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    SER_BAUD    = 115_200

    { I2C configuration }
    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_FREQ    = 400_000                       ' max is 400_000
    ADDR_BITS   = 1                             ' 0, 1
' --

OBJ

    cfg: "core.con.boardcfg.flip"
    imu: "sensor.accel.3dof.mma8452q"
    ser: "com.serial.terminal.ansi"
    time: "time"

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(10)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

#ifdef MMA8452Q_SPI
    if (imu.startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN))
#else
    if (imu.startx(SCL_PIN, SDA_PIN, I2C_FREQ, ADDR_BITS))
#endif
        ser.strln(string("MMA8452Q driver started"))
    else
        ser.strln(string("MMA8452Q driver failed to start - halting"))
        repeat

    imu.preset_active{}

    demo{}

#include "imudemo.common.spinh"                 ' code common to all IMU demos

DAT
{
TERMS OF USE: MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
}

