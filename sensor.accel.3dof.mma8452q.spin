{
    --------------------------------------------
    Filename: sensor.accel.3dof.mma8452q.spin
    Author: Jesse Burt
    Description: Driver for the MMA8452Q 3DoF accelerometer
    Copyright (c) 2022
    Started May 9, 2021
    Updated Nov 5, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "sensor.accel.common.spinh"

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    DEF_ADDR        = 0
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF       = 3
    GYRO_DOF        = 0
    MAG_DOF         = 0
    BARO_DOF        = 0
    DOF             = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

    R               = 0
    W               = 1

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
    SLEEP           = 2

' Accelerometer power modes
    NORMAL          = 0
    LONOISE_LOPWR   = 1
    HIGHRES         = 2
    LOPWR           = 3

' Interrupt sources
    INT_AUTOSLPWAKE = 1 << 7
    INT_TRANS       = 1 << 5
    INT_ORIENT      = 1 << 4
    INT_PULSE       = 1 << 3
    INT_FFALL       = 1 << 2
    INT_DRDY        = 1

' Axis-specific constants
    X_AXIS          = 2
    Y_AXIS          = 1
    Z_AXIS          = 0
    ALL_AXES        = 3

' Orientation
    PORTUP_FR       = %000
    PORTUP_BK       = %001
    PORTDN_FR       = %010
    PORTDN_BK       = %011
    LANDRT_FR       = %100
    LANDRT_BK       = %101
    LANDLT_FR       = %110
    LANDLT_BK       = %111

' Low noise modes
'   NORMAL          = 0
    LOWNOISE        = 1

' Wake on interrupt sources
    WAKE_TRANS      = 1 << 3
    WAKE_ORIENT     = 1 << 2
    WAKE_PULSE      = 1 << 1
    WAKE_FFALL      = 1

' Interrupt active state
    LOW             = 0
    HIGH            = 1

VAR

    long _accel_time_res
    byte _opmode_orig
    byte _addr_bits

OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef MMA8452Q_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.mma8452q"                   ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB null{}
' This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ, DEF_ADDR)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start using custom IO pins and I2C bus frequency
    ' validate I/O pins, bus freq, and I2C address bit(s)
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ and lookdown(ADDR_BITS: 0, 1)
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            _addr_bits := ADDR_BITS << 1
            ' test device bus presence
            if (dev_id{} == core#DEVID_RESP)
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB stop{}
' Stop the driver
    i2c.deinit{}
    _opmode_orig := 0

PUB defaults{}
' Set factory defaults
    reset{}

PUB preset_active{}
' Like defaults(), but enable sensor power, and set scale
    reset{}
    accel_opmode(ACTIVE)
    accel_scale(2)

PUB preset_clickdet{}
' Preset settings for click detection
    reset{}
    accel_data_rate(400)
    accel_scale(2)
    click_axis_ena(%111111)                     ' enable X, Y, Z single tap det
    click_set_thresh_x(1_575000)                ' X: 1.575g thresh
    click_set_thresh_y(1_575000)                ' Y: 1.575g
    click_set_thresh_z(2_650000)                ' Z: 2.650g
    click_set_time(50_000)
    click_set_latency(300_000)
    dbl_click_set_win(300_000)
    accel_int_mask(INT_PULSE)                   ' enable click/pulse interrupts
    accel_int_routing(INT_PULSE)                ' route click ints to INT1 pin
    accel_opmode(ACTIVE)

PUB preset_freefall{}
' Preset settings for free-fall detection
    reset{}
    accel_data_rate(400)
    accel_scale(2)
    freefall_time(30_000)                       ' 30_000us/30ms min time
    freefall_thresh(0_315000)                   ' 0.315g's
    freefall_axis_ena(%111)                     ' all axes
    accel_opmode(ACTIVE)
    accel_int_mask(INT_FFALL)                   ' enable free-fall interrupt
    accel_int_routing(INT_FFALL)                ' route free-fall ints to INT1

PUB dev_id{}: id
' Read device identification
'   Returns: $2A
    id := 0
    readreg(core#WHO_AM_I, 1, @id)

PUB reset{} | tmp
' Reset the device
    tmp := core#RESET
    writereg(core#CTRL_REG2, 1, @tmp)
    time.usleep(core#T_POR)                     ' wait for device to come back

PUB sys_mode{}: sysmod 'XXX temporary
' Read current system mode
'   STDBY, ACTIVE, SLEEP
    sysmod := 0
    readreg(core#SYSMOD, 1, @sysmod)

{ re-use code that's common to other NXP accelerometer drivers }
#include "sensor.accel.nxp.common.spinh"

PRI cache_opmode{}
' Store the current operating mode, and switch to standby if different
'   (required for modifying some registers)
    _opmode_orig := accel_opmode(-2)
    if _opmode_orig <> STDBY                    ' must be in standby to change
        accel_opmode(STDBY)                      '   control regs

PRI restore_opmode{}
' Restore original operating mode
    if _opmode_orig <> STDBY                    ' restore original opmode
        accel_opmode(_opmode_orig)

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        core#OUT_X_MSB, core#OUT_Y_MSB, core#OUT_Z_MSB, {
}       core#STATUS, core#SYSMOD..core#FF_MT_CNT, core#TRANSIENT_CFG..core#OFF_Z:
            cmd_pkt.byte[0] := (SLAVE_WR | _addr_bits)
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.wr_byte(SLAVE_RD | _addr_bits)
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        other:                                  ' invalid reg_nr
            return

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        core#XYZ_DATA_CFG, core#HP_FILT_CUTOFF, core#PL_CFG, core#FF_MT_CFG, {
}       core#FF_MT_THS, core#FF_MT_CNT, core#TRANSIENT_CFG, {
}       core#TRANSIENT_THS..core#PULSE_CFG, core#PULSE_THSX..core#OFF_Z:
            cmd_pkt.byte[0] := (SLAVE_WR | _addr_bits)
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_msbf(ptr_buff, nr_bytes)
            i2c.stop{}
        other:
            return

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
