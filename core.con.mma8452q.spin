{
    --------------------------------------------
    Filename: core.con.mma8452q.spin
    Author:
    Description:
    Copyright (c) 2021
    Started MMMM DDDD, YYYY
    Updated MMMM DDDD, YYYY
    See end of file for terms of use.
    --------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ    = 400_000                   ' device max I2C bus freq
    SLAVE_ADDR      = $1D << 1                  ' 7-bit format slave address
    T_POR           = 2_000                     ' startup time (usecs)

    DEVID_RESP      = $2A                       ' device ID expected response

' Register definitions
    WHO_AM_I        = $0D

PUB Null{}
' This is not a top-level object

