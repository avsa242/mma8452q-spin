{
    --------------------------------------------
    Filename: sensor.accel.3dof.mma8452q.i2c.spin
    Author: Jesse Burt
    Description: Driver for the MMA8452Q 3DoF accelerometer
    Copyright (c) 2021
    Started May 09, 2021
    Updated May 10, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF       = 3
    GYRO_DOF        = 0
    MAG_DOF         = 0
    BARO_DOF        = 0
    DOF             = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

' Scales and data rates used during calibration/bias/offset process
    CAL_XL_SCL      = 2
    CAL_G_SCL       = 0
    CAL_M_SCL       = 0
    CAL_XL_DR       = 800
    CAL_G_DR        = 0
    CAL_M_DR        = 0

' Accelerometer operating modes
    STDBY           = 0
    ACTIVE          = 1

' Axis-specific constants
    X_AXIS          = 2
    Y_AXIS          = 1
    Z_AXIS          = 0
    ALL_AXES        = 3

VAR

    long _ares

OBJ

    i2c : "com.i2c"                             ' PASM I2C engine (up to ~800kHz)
    core: "core.con.mma8452q"                   ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom IO pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ                 ' validate pins and bus freq
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            if i2c.present(SLAVE_WR)            ' test device bus presence
                if deviceid{} == core#DEVID_RESP' validate device 
                    return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB Stop{}

    i2c.deinit{}

PUB Defaults{}
' Set factory defaults
    reset{}

PUB Preset_Active{}
' Like Defaults(), but enable sensor power, and set scale
    accelopmode(ACTIVE)

PUB AccelADCRes(adc_res): curr_res
' dummy method

PUB AccelAxisEnabled(xyz_mask): curr_mask
' dummy method

PUB AccelBias(bias_x, bias_y, bias_z, rw) | tmp, opmode_orig
' Read or write/manually set accelerometer calibration offset values

PUB AccelClearInt{}
' Clear Accelerometer interrupts

PUB AccelData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Read the Accelerometer output registers
    readreg(core#OUT_X_MSB, 6, @tmp)
    long[ptr_x] := ~~tmp.word[X_AXIS] ~> 4      ' output data is 12bit signed,
    long[ptr_y] := ~~tmp.word[Y_AXIS] ~> 4      '   left-justified; shift it
    long[ptr_z] := ~~tmp.word[Z_AXIS] ~> 4      '   down to the LSBit

PUB AccelDataOverrun{}: flag
' Flag indicating previously acquired data has been overwritten
    readreg(core#STATUS, 1, @flag)
    return ((flag & core#ZYX_OW) <> 0)

PUB AccelDataRate(rate): curr_rate | opmode_orig
' Set accelerometer output data rate, in Hz
'   Valid values:
'       1 (1.56), 6 (6.25), 12 (12.5), 50, 100, 200, 400, 800
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case rate
        1, 6, 12, 50, 100, 200, 400, 800:
            rate := lookdownz(rate: 800, 400, 200, 100, 50, 12, 6, 1) << core#DR
        other:
            curr_rate := (curr_rate >> core#DR) & core#DR_BITS
            return lookupz(curr_rate: 800, 400, 200, 100, 50, 12, 6, 1)

    rate := ((curr_rate & core#DR_MASK) | rate)
    opmode_orig := accelopmode(-2)
    if opmode_orig <> STDBY
        accelopmode(STDBY)

    writereg(core#CTRL_REG1, 1, @rate)

    if opmode_orig <> STDBY
        accelopmode(opmode_orig)

PUB AccelDataReady{}: flag
' Flag indicating new accelerometer data available
    readreg(core#STATUS, 1, @flag)
    return ((flag & core#ZYX_DR) <> 0)

PUB AccelG(ptr_x, ptr_y, ptr_z) | tmp[ACCEL_DOF]
' Read the Accelerometer data and scale the outputs to
'   micro-g's (1_000_000 = 1.000000 g = 9.8 m/s/s)
    acceldata(@tmp[X_AXIS], @tmp[Y_AXIS], @tmp[Z_AXIS])
    long[ptr_x] := tmp[X_AXIS] * _ares
    long[ptr_y] := tmp[Y_AXIS] * _ares
    long[ptr_z] := tmp[Z_AXIS] * _ares

PUB AccelInt{}: flag
' Flag indicating accelerometer interrupt asserted

PUB AccelLowPassFilter(freq): curr_freq
' Enable accelerometer data low-pass filter

PUB AccelOpMode(mode): curr_mode
' Set accelerometer operating mode
'   Valid values:
'       STDBY (0): stand-by
'       ACTIVE (1): active
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CTRL_REG1, 1, @curr_mode)
    case mode
        STDBY, ACTIVE:
        other:
            return curr_mode & 1

    mode := ((curr_mode & core#ACTIVE_MASK) | mode)
    writereg(core#CTRL_REG1, 1, @mode)

PUB AccelScale(scale): curr_scl | opmode_orig
' Set the full-scale range of the accelerometer, in g's
    curr_scl := 0
    readreg(core#XYZ_DATA_CFG, 1, @curr_scl)
    case scale
        2, 4, 8:
            scale := lookdownz(scale: 2, 4, 8)
            ' _ares = 1 / 1024 counts/g (2g), 512 (4g), or 256 (8g)
            _ares := lookupz(scale: 0_000976, 0_001953, 0_003906)
        other:
            curr_scl &= core#FS_BITS
            return lookupz(curr_scl: 2, 4, 8)

    scale := ((curr_scl & core#FS_MASK) | scale)
    opmode_orig := accelopmode(-2)
    accelopmode(STDBY)                          ' must be in standby to change

    writereg(core#XYZ_DATA_CFG, 1, @scale)

    if opmode_orig == ACTIVE                    ' restore opmode, if applicable
        accelopmode(ACTIVE)

PUB CalibrateAccel{} | acceltmp[ACCEL_DOF], axis, x, y, z, samples, scale_orig, drate_orig, fifo_orig, scl
' Calibrate the accelerometer

PUB DeviceID{}: id
' Read device identification
'   Returns: $2A
    readreg(core#WHO_AM_I, 1, @id)

PUB IntClear(mask)
' Clear interrupts, per clear_mask

PUB Interrupt{}: src
' Indicate interrupt state

PUB IntMask(mask): curr_mask
' Set interrupt mask

PUB Reset{} | tmp
' Reset the device
    tmp := core#RESET
    writereg(core#CTRL_REG2, 1, @tmp)
    time.usleep(core#T_POR)                     ' wait for device to come back

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        core#OUT_X_MSB, core#OUT_Y_MSB, core#OUT_Z_MSB, {
}       core#STATUS, core#SYSMOD..core#FF_MT_CNT, core#TRANSIENT_CFG..core#OFF_Z:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.wr_byte(SLAVE_RD)
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        other:                                  ' invalid reg_nr
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        core#XYZ_DATA_CFG, core#HP_FILT_CUTOFF, core#PL_CFG, core#FF_MT_CFG, {
}       core#FF_MT_THS, core#FF_MT_CNT, core#TRANSIENT_CFG, {
}       core#TRANSIENT_THS..core#PULSE_CFG, core#PULSE_THSX..core#OFF_Z:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_msbf(ptr_buff, nr_bytes)
            i2c.stop{}
        other:
            return


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
