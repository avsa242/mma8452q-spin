{
    --------------------------------------------
    Filename: MMA8452Q-Demo.spin
    Author: Jesse Burt
    Description: Demo of the MMA8452Q driver
    Copyright (c) 2021
    Started May 09, 2021
    Updated May 09, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-defined constants
    LED         = cfg#LED1
    SER_BAUD    = 115_200

    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_HZ      = 400_000                       ' max is 400_000

' --

OBJ

    cfg   : "core.con.boardcfg.flip"
    ser   : "com.serial.terminal.ansi"
    time  : "time"
    accel : "sensor.accel.3dof.mma8452q.i2c"

PUB Main{} | x, y, z

    setup{}
    accel.accelopmode(1)
    ser.dec(accel.accelopmode(-2))
    repeat
        repeat until accel.acceldataready{}
        accel.acceldata(@x, @y, @z)
        ser.position(0, 5)
        ser.printf3(string("%x  %x  %x"), x, y, z)

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if accel.startx(SCL_PIN, SDA_PIN, I2C_HZ)
        ser.strln(string("MMA8452Q terminal started"))
    else
        ser.strln(string("MMA8452Q terminal failed to start - halting"))
        repeat

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}