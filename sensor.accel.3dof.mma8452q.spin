{
    --------------------------------------------
    Filename: sensor.accel.3dof.mma8452q.spin
    Author: Jesse Burt
    Description: Driver for the MMA8452Q 3DoF accelerometer
    Copyright (c) 2022
    Started May 9, 2021
    Updated Jul 21, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "sensor.imu.common.spinh"

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

    byte _opmode_orig

OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef MMA8452Q_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.mma8452q"                   ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ, DEF_ADDR)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start using custom IO pins and I2C bus frequency
    ' validate I/O pins, bus freq, and I2C address bit(s)
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ and lookdown(ADDR_BITS: 0, 1)
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            _addr_bits := ADDR_BITS << 1
            ' test device bus presence
            if i2c.present(SLAVE_WR | _addr_bits)
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
    reset{}
    accelopmode(ACTIVE)
    accelscale(2)

PUB Preset_ClickDet{}
' Preset settings for click detection
    reset{}
    acceldatarate(400)
    accelscale(2)
    clickaxisenabled(%111111)                   ' enable X, Y, Z single tap det
    clickthreshx(1_575000)                      ' X: 1.575g thresh
    clickthreshy(1_575000)                      ' Y: 1.575g
    clickthreshz(2_650000)                      ' Z: 2.650g
    clicktime(50_000)
    clicklatency(300_000)
    doubleclickwindow(300_000)
    intmask(INT_PULSE)                          ' enable click/pulse interrupts
    introuting(INT_PULSE)                       ' route click ints to INT1 pin
    accelopmode(ACTIVE)

PUB Preset_FreeFall{}
' Preset settings for free-fall detection
    reset{}
    acceldatarate(400)
    accelscale(2)
    freefalltime(30_000)                        ' 30_000us/30ms min time
    freefallthresh(0_315000)                    ' 0.315g's
    freefallaxisenabled(%111)                   ' all axes
    accelopmode(ACTIVE)
    intmask(INT_FFALL)                          ' enable free-fall interrupt
    introuting(INT_FFALL)                       ' route free-fall ints to INT1

PUB AccelADCRes(adc_res): curr_res
' dummy method

PUB AccelAxisEnabled(xyz_mask): curr_mask
' dummy method

PUB AccelBias(bias_x, bias_y, bias_z, rw) | tmp
' Read or write/manually set accelerometer calibration offset values
'   Valid values:
'       rw:
'           R (0), W (1)
'       bias_x, bias_y, bias_z:
'           -128..127
'   NOTE: When rw is set to READ, bias_x, bias_y and bias_z must be pointers
'       to respective variables to hold the returned calibration offset values
    tmp := 0
    case rw
        R:
            readreg(core#OFF_X, 3, @tmp)
            _abias[X_AXIS] := long[bias_x] := ~tmp.byte[X_AXIS]
            _abias[Y_AXIS] := long[bias_y] := ~tmp.byte[Y_AXIS]
            _abias[Z_AXIS] := long[bias_z] := ~tmp.byte[Z_AXIS]
            return
        W:
            case bias_x
                -128..127:
                    _abias[X_AXIS] := -bias_x
                other:
                    return
            case bias_y
                -128..127:
                    _abias[Y_AXIS] := -bias_y
                other:
                    return
            case bias_z
                -128..127:
                    _abias[Z_AXIS] := -bias_z
                other:
                    return
            cacheopmode{}                       ' switch to stdby to mod regs
            writereg(core#OFF_X, 1, @_abias[X_AXIS])
            writereg(core#OFF_Y, 1, @_abias[Y_AXIS])
            writereg(core#OFF_Z, 1, @_abias[Z_AXIS])
            restoreopmode{}                     ' restore original opmode

PUB AccelData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Read the Accelerometer output registers
    readreg(core#OUT_X_MSB, 6, @tmp)
    long[ptr_x] := ~~tmp.word[X_AXIS] ~> 4      ' output data is 12bit signed,
    long[ptr_y] := ~~tmp.word[Y_AXIS] ~> 4      '   left-justified; shift it
    long[ptr_z] := ~~tmp.word[Z_AXIS] ~> 4      '   down to the LSBit

PUB AccelDataOverrun{}: flag
' Flag indicating previously acquired data has been overwritten
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return ((flag & core#ZYX_OW) <> 0)

PUB AccelDataRate(rate): curr_rate
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
    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#CTRL_REG1, 1, @rate)
    restoreopmode{}                             ' restore original opmode

PUB AccelDataReady{}: flag
' Flag indicating new accelerometer data available
    flag := 0
    readreg(core#STATUS, 1, @flag)
    return ((flag & core#ZYX_DR) <> 0)

PUB AccelHPFEnabled(state): curr_state
' Enable accelerometer data high-pass filter
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#XYZ_DATA_CFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#HPF_OUT
        other:
            return (((curr_state >> core#HPF_OUT) & 1) == 1)

    state := ((curr_state & core#HPF_OUT_MASK) | state)
    writereg(core#XYZ_DATA_CFG, 1, @state)

PUB AccelHPFreq(freq): curr_freq
' Set accelerometer data high-pass cutoff frequency, in milli-Hz
'   Valid values:
'   AccelPowerMode(): NORMAL
'   AccelDataRate():    800, 400    200     100     50, 12, 6, 1
'                       16_000      8_000   4_000   2_000
'                       8_000       4_000   2_000   1_000
'                       4_000       2_000   1_000   500
'                       2_000       1_000   500     250
'   AccelPowerMode(): LONOISE_LOPWR
'   AccelDataRate():    800, 400    200     100     50      12, 6, 1
'                       16_000      8_000   4_000   2_000   500
'                       8_000       4_000   2_000   1_000   250
'                       4_000       2_000   1_000   500     125
'                       2_000       1_000   500     250     63
'   AccelPowerMode(): HIGHRES
'   AccelDataRate():    All
'                       16_000
'                       8_000
'                       4_000
'                       2_000
'   AccelPowerMode(): LOPWR
'   AccelDataRate():    800     400     200     100     50      12, 6, 1
'                       16_000  8_000   4_000   2_000   1_000   250
'                       8_000   4_000   2_000   1_000   500     125
'                       4_000   2_000   1_000   500     250     63
'                       2_000   1_000   500     250     125     31
'   Any other value polls the chip and returns the current setting
    curr_freq := 0
    readreg(core#HP_FILT_CUTOFF, 1, @curr_freq)
    case accelpowermode(-2)
        NORMAL:
            case acceldatarate(-2)
                800, 400:
                    case freq
                        16_000, 8_000, 4_000, 2_000:
                            freq := lookdownz(freq: 16_000, 8_000, 4_000, 2_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 16_000, 8_000, 4_000, 2_000)
                200:
                    case freq
                        8_000, 4_000, 2_000, 1_000:
                            freq := lookdownz(freq: 8_000, 4_000, 2_000, 1_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 8_000, 4_000, 2_000, 1_000)
                100:
                    case freq
                        4_000, 2_000, 1_000, 500:
                            freq := lookdownz(freq: 4_000, 2_000, 1_000, 500)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 4_000, 2_000, 1_000, 500)
                50, 12, 6, 1:
                    case freq
                        2_000, 1_000, 500, 250:
                            freq := lookdownz(freq: 2_000, 1_000, 500, 250)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 2_000, 1_000, 500, 250)
        LONOISE_LOPWR:
            case acceldatarate(-2)
                800, 400:
                    case freq
                        16_000, 8_000, 4_000, 2_000:
                            freq := lookdownz(freq: 16_000, 8_000, 4_000, 2_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 16_000, 8_000, 4_000, 2_000)
                200:
                    case freq
                        8_000, 4_000, 2_000, 1_000:
                            freq := lookdownz(freq: 8_000, 4_000, 2_000, 1_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 8_000, 4_000, 2_000, 1_000)
                100:
                    case freq
                        4_000, 2_000, 1_000, 500:
                            freq := lookdownz(freq: 4_000, 2_000, 1_000, 500)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 4_000, 2_000, 1_000, 500)
                50:
                    case freq
                        2_000, 1_000, 500, 250:
                            freq := lookdownz(freq: 2_000, 1_000, 500, 250)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 2_000, 1_000, 500, 250)
                12, 6, 1:
                    case freq
                        500, 250, 125, 63:
                            freq := lookdownz(freq: 500, 250, 125, 63)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 500, 250, 125, 63)
        HIGHRES:
            case freq
                2_000, 4_000, 8_000, 16_000:
                    freq := lookdownz(freq: 16_000, 8_000, 4_000, 2_000)
        LOPWR:
            case acceldatarate(-2)
                800:
                    case freq
                        16_000, 8_000, 4_000, 2_000:
                            freq := lookdownz(freq: 16_000, 8_000, 4_000, 2_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 16_000, 8_000, 4_000, 2_000)
                400:
                    case freq
                        8_000, 4_000, 2_000, 1_000:
                            freq := lookdownz(freq: 8_000, 4_000, 2_000, 1_000)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 8_000, 4_000, 2_000, 1_000)
                200:
                    case freq
                        4_000, 2_000, 1_000, 500:
                            freq := lookdownz(freq: 4_000, 2_000, 1_000, 500)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 4_000, 2_000, 1_000, 500)
                100:
                    case freq
                        2_000, 1_000, 500, 250:
                            freq := lookdownz(freq: 2_000, 1_000, 500, 250)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 2_000, 1_000, 500, 250)
                50:
                    case freq
                        1_000, 500, 250, 125:
                            freq := lookdownz(freq: 1_000, 500, 250, 125)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 1_000, 500, 250, 125)
                12, 6, 1:
                    case freq
                        250, 125, 63, 31:
                            freq := lookdownz(freq: 250, 125, 63, 31)
                        other:
                            curr_freq &= core#SEL_BITS
                            return lookupz(curr_freq: 250, 125, 63, 31)
    freq := ((curr_freq & core#SEL_MASK) | freq)
    writereg(core#HP_FILT_CUTOFF, 1, @freq)

PUB AccelInt{}: flag
' Flag indicating accelerometer interrupt asserted

PUB AccelLowNoiseMode(mode): curr_mode    'XXX tentatively named
' Set accelerometer low noise mode
'   Valid values:
'       NORMAL (0), LOWNOISE (1)
'   Any other value polls the chip and returns the current setting
'   NOTE: When mode is LOWNOISE, range is limited to +/- 4g
'       This also affects set interrupt thresholds
'       (i.e., values outside 4g would never be reached)
    curr_mode := 0
    readreg(core#CTRL_REG1, 1, @curr_mode)
    case mode
        0, 1:
            mode <<= core#LNOISE
        other:
            return ((curr_mode >> core#LNOISE) & 1)

    cacheopmode{}                               ' switch to stdby to mod regs
    mode := ((curr_mode & core#LNOISE_MASK) | mode)
    writereg(core#CTRL_REG1, 1, @mode)
    restoreopmode{}                             ' restore original opmode

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

PUB AccelPowerMode(mode): curr_mode ' XXX tentatively named
' Set accelerometer power mode/oversampling mode, when active
'   Valid values:
'       NORMAL (0): Normal
'       LONOISE_LOPWR (1): Low noise low power
'       HIGHRES (2): High resolution
'       LOPWR (3): Low power
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CTRL_REG2, 1, @curr_mode)
    case mode
        NORMAL, LONOISE_LOPWR, HIGHRES, LOPWR:
        other:
            return curr_mode & core#MODS_BITS

    mode := ((curr_mode & core#MODS_MASK) | mode)

    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#CTRL_REG2, 1, @mode)
    restoreopmode{}                             ' restore original opmode

PUB AccelScale(scale): curr_scl
' Set the full-scale range of the accelerometer, in g's
    curr_scl := 0
    readreg(core#XYZ_DATA_CFG, 1, @curr_scl)
    case scale
        2, 4, 8:
            scale := lookdownz(scale: 2, 4, 8)
            ' _ares = 1 / 1024 counts/g (2g), 512 (4g), or 256 (8g)
            ' micro-gs per LSB
            _ares := lookupz(scale: 0_000976, 0_001953, 0_003906)
        other:
            curr_scl &= core#FS_BITS
            return lookupz(curr_scl: 2, 4, 8)

    scale := ((curr_scl & core#FS_MASK) | scale)
    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#XYZ_DATA_CFG, 1, @scale)
    restoreopmode{}                             ' restore original opmode

PUB AccelSelfTest(state): curr_state
' Enable accelerometer self-test
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   During self-test, the output data changes approximately as follows
'       (typ. values @ 4g full-scale)
'       X: +0.085g (44LSB * 1953 micro-g per LSB)
'       Y: +0.119g (61LSB * 1953 micro-g per LSB)
'       Z: +0.765g (392LSB * 1953 micro-g per LSB)
    curr_state := 0
    readreg(core#CTRL_REG2, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#ST
        other:
            return (((curr_state >> core#ST) & 1) == 1)

    cacheopmode{}
    state := ((curr_state & core#ST_MASK) | state)
    writereg(core#CTRL_REG2, 1, @state)
    restoreopmode{}

PUB AccelSleepPwrMode(mode): curr_mode
' Set accelerometer power mode/oversampling mode, when sleeping
'   Valid values:
'       NORMAL (0): Normal
'       LONOISE_LOPWR (1): Low noise low power
'       HIGHRES (2): High resolution
'       LOPWR (3): Low power
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#CTRL_REG2, 1, @curr_mode)
    case mode
        NORMAL, LONOISE_LOPWR, HIGHRES, LOPWR:
            mode <<= core#SMODS
        other:
            return ((curr_mode >> core#SMODS) & core#SMODS_BITS)

    cacheopmode{}
    mode := ((curr_mode & core#SMODS_MASK) | mode)
    writereg(core#CTRL_REG2, 1, @mode)
    restoreopmode{}

PUB AutoSleep(state): curr_state
' Enable automatic transition to sleep state when inactive
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL_REG2, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#SLPE
        other:
            return (((curr_state >> core#SLPE) & 1) == 1)

    cacheopmode{}
    state := ((curr_state & core#SLPE_MASK) | state)
    writereg(core#CTRL_REG2, 1, @state)
    restoreopmode{}

PUB AutoSleepDataRate(rate): curr_rate
' Set accelerometer output data rate, in Hz, when in sleep mode
'   Valid values: 1, 6, 12, 50
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CTRL_REG1, 1, @curr_rate)
    case rate
        1, 6, 12, 50:
            rate := lookdownz(rate: 50, 12, 6, 1) << core#ASLP_RATE
        other:
            curr_rate := ((curr_rate >> core#ASLP_RATE) & core#ASLP_RATE_BITS)
            return lookupz(curr_rate: 50, 12, 6, 1)

    cacheopmode{}
    rate := ((curr_rate & core#ASLP_RATE_MASK) | rate)
    writereg(core#CTRL_REG1, 1, @rate)
    restoreopmode{}

PUB ClickAxisEnabled(mask): curr_mask
' Enable click detection per axis, and per click type
'   Valid values:
'       Bits: 5..0
'       [5..4]: Z-axis double-click..single-click
'       [3..2]: Y-axis double-click..single-click
'       [1..0]: X-axis double-click..single-click
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#PULSE_CFG, 1, @curr_mask)
    case mask
        %000000..%111111:
        other:
            return curr_mask & core#PEFE_BITS

    mask := ((curr_mask & core#PEFE_MASK) | mask)
    writereg(core#PULSE_CFG, 1, @mask)

PUB Clicked{}: flag
' Flag indicating the sensor was single or double-clicked
'   Returns: TRUE (-1) if sensor was single-clicked or double-clicked
'            FALSE (0) otherwise
    return (((clickedint{} >> core#EA) & 1) <> 0)

PUB ClickedInt{}: status
' Clicked interrupt status
'   Bits: 7..0
'       7: Interrupt active
'       6: Z-axis clicked
'       5: Y-axis clicked
'       4: X-axis clicked
'       3: Double-click on first event
'       2: Z-axis polarity (0: positive, 1: negative)
'       1: Y-axis polarity (0: positive, 1: negative)
'       0: X-axis polarity (0: positive, 1: negative)
    readreg(core#PULSE_SRC, 1, @status)

PUB ClickIntEnabled(state): curr_state
' Enable click interrupts on INT1
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    readreg(core#CTRL_REG4, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#INT_EN_PULSE
        other:
            return ((curr_state >> core#INT_EN_PULSE) == 1)

    state := ((curr_state & core#IE_PULSE_MASK) | state)
    writereg(core#CTRL_REG4, 1, @state)

PUB ClickLatency(ltime): curr_ltime | time_res, odr
'   Set minimum elapsed time from detection of first click to recognition of
'       any subsequent clicks (single or double), in microseconds. All clicks
'       *during* this time will be ignored.
'   Valid values:
'                                   Max time range
'                           ClickLPFEnabled()
'       AccelDataRate():    == 0        == 1
'       800                 318_000     638_000
'       400                 318_000     1_276_000
'       200                 638_000     2_560_000
'       100                 1_276_000   5_100_000
'       50                  2_560_000   10_200_000
'       12                  2_560_000   10_200_000
'       6                   2_560_000   10_200_000
'       1                   2_560_000   10_200_000
'   Any other value polls the chip and returns the current setting
    ' calc time resolution (in microseconds) based on AccelDataRate() (1/ODR),
    '   then limit to range spec'd in AN4072
    odr := acceldatarate(-2)
    if clicklpfenabled(-2)
        time_res := 2_500 #> ((1_000000/odr) * 2) <# 40_000
    else
        time_res := 1_250 #> ((1_000000/odr) / 2) <# 10_000

    ' check that the parameter is between 0 and the max time range for
    '   the current AccelDataRate() setting
    if (ltime => 0) and (ltime =< (time_res * 255))
        ltime /= time_res
        writereg(core#PULSE_LTCY, 1, @ltime)
    else
        readreg(core#PULSE_LTCY, 1, @curr_ltime)
        return (curr_ltime * time_res)

PUB ClickLPFEnabled(state): curr_state
' Enable click detection low-pass filter
'   Valid Values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#HP_FILT_CUTOFF, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#PLS_LPF_EN
        other:
            return (((curr_state >> core#PLS_LPF_EN) & 1) == 1)

    state := ((curr_state & core#PLS_LPF_EN_MASK) | state)
    writereg(core#HP_FILT_CUTOFF, 1, @state)

PUB ClickThresh(thresh): curr_thresh
' Set threshold for recognizing a click (all axes), in micro-g's
'   Valid values:
'       0..8_000000 (8g's)
'   NOTE: The allowed range is fixed at 8g's, regardless of the current
'       setting of AccelScale()
'   NOTE: If AccelLowNoiseMode() is set to LOWNOISE, the maximum threshold
'       recognized using this method will be 4_000000 (4g's)
    case thresh
        0..8_000000:
            clickthreshx(thresh)
            clickthreshy(thresh)
            clickthreshz(thresh)
        other:
            return

PUB ClickThreshX(thresh): curr_thresh
' Set threshold for recognizing a click (X-axis), in micro-g's
'   Valid values:
'       0..8_000000 (8g's)
'   Any other value polls the chip and returns the current setting
'   NOTE: The allowed range is fixed at 8g's, regardless of the current
'       setting of AccelScale()
'   NOTE: If AccelLowNoiseMode() is set to LOWNOISE, the maximum threshold
'       recognized using this method will be 4_000000 (4g's)
    case thresh
        0..8_000000:
            thresh /= 0_063000
            writereg(core#PULSE_THSX, 1, @thresh)
        other:
            readreg(core#PULSE_THSX, 1, @curr_thresh)
            return curr_thresh * 0_063000       ' scale to 1..8_000000 (8g's)

PUB ClickThreshY(thresh): curr_thresh
' Set threshold for recognizing a click (Y-axis), in micro-g's
'   Valid values:
'       0..8_000000 (8g's)
'   Any other value polls the chip and returns the current setting
'   NOTE: The allowed range is fixed at 8g's, regardless of the current
'       setting of AccelScale()
'   NOTE: If AccelLowNoiseMode() is set to LOWNOISE, the maximum threshold
'       recognized using this method will be 4_000000 (4g's)
    case thresh
        0..8_000000:
            thresh /= 0_063000
            writereg(core#PULSE_THSY, 1, @thresh)
        other:
            readreg(core#PULSE_THSY, 1, @curr_thresh)
            return curr_thresh * 0_063000       ' scale to 1..8_000000 (8g's)

PUB ClickThreshZ(thresh): curr_thresh
' Set threshold for recognizing a click (Z-axis), in micro-g's
'   Valid values:
'       0..8_000000 (8g's)
'   Any other value polls the chip and returns the current setting
'   NOTE: The allowed range is fixed at 8g's, regardless of the current
'       setting of AccelScale()
'   NOTE: If AccelLowNoiseMode() is set to LOWNOISE, the maximum threshold
'       recognized using this method will be 4_000000 (4g's)
    case thresh
        0..8_000000:
            thresh /= 0_063000
            writereg(core#PULSE_THSZ, 1, @thresh)
        other:
            readreg(core#PULSE_THSZ, 1, @curr_thresh)
            return curr_thresh * 0_063000       ' scale to 1..8_000000 (8g's)

PUB ClickTime(ctime): curr_ctime | time_res, odr
' Set maximum elapsed interval between start of click and end of click, in uSec
'   (i.e., time from set ClickThresh exceeded to falls back below threshold)
'   Valid values:
'                                   Max time range
'                           ClickLPFEnabled()
'       AccelDataRate():    == 0        == 1
'       800                 159_000     319_000
'       400                 159_000     638_000
'       200                 319_000     1_280_000
'       100                 638_000     2_550_000
'       50                  1_280_000   5_100_000
'       12                  1_280_000   5_100_000
'       6                   1_280_000   5_100_000
'       1                   1_280_000   5_100_000
'   Any other value polls the chip and returns the current setting
    ' calc time resolution (in microseconds) based on AccelDataRate() (1/ODR),
    '   then limit to range spec'd in AN4072
    odr := acceldatarate(-2)
    if clicklpfenabled(-2)
        time_res := 1_250 #> ((1_000000/odr)) <# 20_000
    else
        time_res := 0_625 #> ((1_000000/odr) / 4) <# 5_000

    ' check that the parameter is between 0 and the max time range for
    '   the current AccelDataRate() setting
    if (ctime => 0) and (ctime =< (time_res * 255))
        ctime /= time_res
        writereg(core#PULSE_TMLT, 1, @ctime)
    else
        readreg(core#PULSE_TMLT, 1, @curr_ctime)
        return (curr_ctime * time_res)

PUB DoubleClickWindow(dctime): curr_dctime | time_res, odr
' Set maximum elapsed interval between two consecutive clicks, in uSec
'   Valid values:
'                                   Max time range
'                           ClickLPFEnabled()
'       AccelDataRate():    == 0        == 1
'       800                 318_000     638_000
'       400                 318_000     1_276_000
'       200                 638_000     2_560_000
'       100                 1_276_000   5_100_000
'       50                  2_560_000   10_200_000
'       12                  2_560_000   10_200_000
'       6                   2_560_000   10_200_000
'       1                   2_560_000   10_200_000
'   Any other value polls the chip and returns the current setting
    ' calc time resolution (in microseconds) based on AccelDataRate() (1/ODR),
    '   then limit to range spec'd in AN4072
    odr := acceldatarate(-2)
    if clicklpfenabled(-2)
        time_res := 2_500 #> ((1_000000/odr) * 2) <# 40_000
    else
        time_res := 1_250 #> ((1_000000/odr) / 2) <# 10_000

    ' check that the parameter is between 0 and the max time range for
    '   the current AccelDataRate() setting
    if (dctime => 0) and (dctime =< (time_res * 255))
        dctime /= time_res
        writereg(core#PULSE_WIND, 1, @dctime)
    else
        readreg(core#PULSE_WIND, 1, @curr_dctime)
        return (curr_dctime * time_res)

PUB DeviceID{}: id
' Read device identification
'   Returns: $2A
    readreg(core#WHO_AM_I, 1, @id)

PUB FreeFallAxisEnabled(mask): curr_mask
' Enable free-fall detection, per axis mask
'   Valid values: %000..%111 (ZYX)
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#FF_MT_CFG, 1, @curr_mask)
    case mask
        %000..%111:
            mask <<= core#FEFE
        other:
            return ((curr_mask >> core#FEFE) & core#FEFE_BITS)

    mask := ((curr_mask & core#FEFE_MASK) | mask)
    writereg(core#FF_MT_CFG, 1, @mask)

PUB FreeFallThresh(thresh): curr_thr
' Set free-fall threshold, in micro-g's
'   Valid values: 0..8_001000 (0..8g's)
'   Any other value polls the chip and returns the current setting
    curr_thr := 0
    readreg(core#FF_MT_THS, 1, @curr_thr)
    case thresh
        0..8_001000:
            thresh /= 0_063000
        other:
            return ((curr_thr & core#FF_THS_BITS) * 0_063000)

    thresh := ((curr_thr & core#FF_THS_MASK) | thresh)
    writereg(core#FF_MT_THS, 1, @thresh)

PUB FreeFallTime(fftime): curr_time | odr, time_res, max_dur
' Set minimum time duration required to recognize free-fall, in microseconds
'   Valid values: 0..maximum in table below:
'                           AccelPowerMode():
'       AccelDataRate():    NORMAL     LONOISE_LOPWR   HIGHRES     LOPWR
'       800Hz               319_000    319_000         319_000     319_000
'       400                 638_000    638_000         638_000     638_000
'       200                 1_280      1_280           638_000     1_280
'       100                 2_550      2_550           638_000     2_550
'       50                  5_100      5_100           638_000     5_100
'       12                  5_100      20_400          638_000     20_400
'       6                   5_100      20_400          638_000     40_800
'       1                   5_100      20_400          638_000     40_800
'   Any other value polls the chip and returns the current setting
    odr := acceldatarate(-2)
    case accelpowermode(-2)
        NORMAL:
            time_res := 1_250 #> (1_000000/odr) <# 20_000
        LONOISE_LOPWR:
            time_res := 1_250 #> (1_000000/odr) <# 80_000
        HIGHRES:
            time_res := 1_250 #> (1_000000/odr) <# 2_500
        LOPWR:
            time_res := 1_250 #> (1_000000/odr) <# 160_000

    max_dur := (time_res * 255)

    case fftime
        0..max_dur:
            fftime /= time_res
            writereg(core#FF_MT_CNT, 1, @fftime)
        other:
            curr_time := 0
            readreg(core#FF_MT_CNT, 1, @curr_time)
            return (curr_time * time_res)

PUB GyroAxisEnabled(xyzmask)
' Dummy method

PUB GyroBias(x, y, z, rw)
' Dummy method

PUB GyroData(x, y, z)
' Dummy method

PUB GyroDataRate(hz)
' Dummy method

PUB GyroDataReady
' Dummy method

PUB GyroOpMode(mode)
' Dummy method

PUB GyroScale(scale)
' Dummy method

PUB InactInt(mask): curr_mask
' Set inactivity interrupt mask
'   Valid values:
'       Bits [3..0]
'       3: Wake on transient interrupt
'       2: Wake on orientation interrupt
'       1: Wake on pulse/click/tap interrupt
'       0: Wake on free-fall/motion interrupt
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#CTRL_REG3, 1, @curr_mask)
    case mask
        %0000..%1111:
            mask <<= core#WAKE
        other:
            return ((curr_mask >> core#WAKE) & core#WAKE_BITS)

    cacheopmode{}
    mask := ((curr_mask & core#WAKE_MASK) | mask)
    writereg(core#CTRL_REG3, 1, @mask)
    restoreopmode{}

PUB InactThresh(thresh): curr_thr
' Set inactivity threshold, in micro-g's
'   Valid values: TBD
'   Any other value polls the chip and returns the current setting
    curr_thr := 0
    readreg(core#TRANSIENT_THS, 1, @curr_thr)
    case thresh
        0..$7f:
            writereg(core#TRANSIENT_THS, 1, @thresh)
        other:
            return curr_thr

PUB InactTime(itime): curr_itime | max_dur, time_res
' Set inactivity time, in milliseconds
'   Valid values:
'       0..163_200 (AccelDataRate() == 1)
'       0..81_600 (AccelDataRate() == all other settings)
'   Any other value polls the chip and returns the current setting
'   NOTE: Setting this to 0 will generate an interrupt when the acceleration
'       measures less than that set with InactThresh()
    if acceldatarate(-2) == 1
        time_res := 640                         ' 640ms time step for 1Hz ODR
    else
        time_res := 320                         ' 320ms time step for others
    max_dur := (time_res * 255)                 ' calc max possible duration
    case itime
        0..max_dur:
            cacheopmode{}
            itime := (itime / time_res)
            writereg(core#ASLP_CNT, 1, @itime)
            restoreopmode{}
        other:
            curr_itime := 0
            readreg(core#ASLP_CNT, 1, @curr_itime)
            return (curr_itime * time_res)

PUB InFreeFall{}: flag
' Flag indicating device is in free-fall
'   Returns:
'       TRUE (-1): device is in free-fall
'       FALSE (0): device isn't in free-fall
    flag := 0
    readreg(core#FF_MT_SRC, 1, @flag)
    return (((flag >> core#FEA) & 1) == 1)

PUB IntActiveState(state): curr_state
' Set interrupt pin active state/logic level
'   Valid values: LOW (0), HIGH (1)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#CTRL_REG3, 1, @curr_state)
    case state
        LOW, HIGH:
            state <<= core#IPOL
        other:
            return ((curr_state >> core#IPOL) & 1)

    cacheopmode{}
    state := ((curr_state & core#IPOL_MASK) | state)
    writereg(core#CTRL_REG3, 1, @state)
    restoreopmode{}

PUB IntClear(mask)
' Clear interrupts, per clear_mask

PUB Interrupt{}: src
' Flag indicating one or more interrupts asserted
'   Interrupt flags:
'       Bits [7..0] (OR together symbols, as needed)
'       7: INT_AUTOSLPWAKE - Auto-sleep/wake
'       6: NOT USED (will be masked off to 0)
'       5: INT_TRANS - Transient
'       4: INT_ORIENT - Orientation (landscape/portrait)
'       3: INT_PULSE - Pulse detection
'       2: INT_FFALL - Freefall/motion
'       1: NOT USED (will be masked off to 0)
'       0: INT_DRDY - Data ready
    readreg(core#INT_SOURCE, 1, @src)

PUB IntMask(mask): curr_mask
' Set interrupt mask
'   Valid values:
'       Bits [7..0] (OR together symbols, as needed)
'       7: INT_AUTOSLPWAKE - Auto-sleep/wake
'       6: NOT USED (will be masked off to 0)
'       5: INT_TRANS - Transient
'       4: INT_ORIENT - Orientation (landscape/portrait)
'       3: INT_PULSE - Pulse detection
'       2: INT_FFALL - Freefall/motion
'       1: NOT USED (will be masked off to 0)
'       0: INT_DRDY - Data ready
'   Any other value polls the chip and returns the current setting
    case mask
        %00000000..%10111101:
            mask &= core#CTRL_REG4_MASK
            cacheopmode{}                       ' switch to stdby to mod regs
            writereg(core#CTRL_REG4, 1, @mask)
            restoreopmode{}                     ' restore original opmode
        other:
            readreg(core#CTRL_REG4, 1, @curr_mask)
            return

PUB IntRouting(mask): curr_mask
' Set routing of interrupt sources to INT1 or INT2 pin
'   Valid values:
'       Setting a bit routes the interrupt to INT1
'       Clearing a bit routes the interrupt to INT2
'
'       Bits [7..0] (OR together symbols, as needed)
'       7: INT_AUTOSLPWAKE - Auto-sleep/wake
'       6: NOT USED (will be masked off to 0)
'       5: INT_TRANS - Transient
'       4: INT_ORIENT - Orientation (landscape/portrait)
'       3: INT_PULSE - Pulse detection
'       2: INT_FFALL - Freefall/motion
'       1: NOT USED (will be masked off to 0)
'       0: INT_DRDY - Data ready
'   Any other value polls the chip and returns the current setting
    case mask
        %00000000..%10111101:
            mask &= core#CTRL_REG5_MASK
            cacheopmode{}                       ' switch to stdby to mod regs
            writereg(core#CTRL_REG5, 1, @mask)
            restoreopmode{}                     ' restore original opmode
        other:
            readreg(core#CTRL_REG5, 1, @curr_mask)
            return

PUB MagBias(x, y, z, rw)
' Dummy method

PUB MagData(x, y, z)
' Dummy method

PUB MagDataRate(hz)
' Dummy method

PUB MagDataReady{}
' Dummy method

PUB MagOpMode(mode)
' Dummy method

PUB MagScale(scale)
' Dummy method

PUB Orientation{}: curr_or
' Current orientation
'   Returns:
'       %000: portrait-up, front-facing
'       %001: portrait-up, back-facing
'       %010: portrait-down, front-facing
'       %011: portrait-down, back-facing
'       %100: landscape-right, front-facing
'       %101: landscape-right, back-facing
'       %110: landscape-left, front-facing
'       %111: landscape-left, back-facing
    curr_or := 0
    readreg(core#PL_STATUS, 1, @curr_or)
    return (curr_or & core#LAPOBAFRO_BITS)

PUB OrientDetect(state): curr_state
' Enable orientation detection
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
    curr_state := 0
    readreg(core#PL_CFG, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#PL_EN
        other:
            return ((curr_state >> core#PL_EN) & 1) == 1

    state := ((curr_state & core#PL_EN_MASK) | state)
    cacheopmode{}                               ' switch to stdby to mod regs
    writereg(core#PL_CFG, 1, @state)
    restoreopmode{}                             ' restore original opmode

PUB Reset{} | tmp
' Reset the device
    tmp := core#RESET
    writereg(core#CTRL_REG2, 1, @tmp)
    time.usleep(core#T_POR)                     ' wait for device to come back

PUB SysMode{}: sysmod 'XXX temporary
' Read current system mode
'   STDBY, ACTIVE, SLEEP
    sysmod := 0
    readreg(core#SYSMOD, 1, @sysmod)

PUB TransCount(tcnt): curr_tcnt
' Set minimum number of debounced samples that must be greater than the
'   threshold set by TransThresh() to generate an interrupt
'   Valid values: 0..255
'   Any other value polls the chip and returns the current setting
    case tcnt
        0..255:
            writereg(core#TRANSIENT_CNT, 1, @tcnt)
        other:
            curr_tcnt := 0
            readreg(core#TRANSIENT_CNT, 1, @curr_tcnt)

PUB TransAxisEnabled(axis_mask): curr_mask
' Enable transient acceleration detection, per mask
'   Valid values:
'       Bits [2..0]
'       2: Enable transient acceleration interrupt on Z-axis
'       1: Enable transient acceleration interrupt on Y-axis
'       0: Enable transient acceleration interrupt on X-axis
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#TRANSIENT_CFG, 1, @curr_mask)
    case axis_mask
        %000..%111:
            axis_mask <<= core#TEFE
        other:
            return ((curr_mask >> core#TEFE) & core#TEFE_MASK)

    cacheopmode{}
    axis_mask := ((curr_mask & core#TEFE_MASK) | axis_mask) | 1 << core#TELE
    writereg(core#TRANSIENT_CFG, 1, @axis_mask)
    restoreopmode{}

PUB TransInterrupt{}: int_src
' Read transient acceleration interrupt(s)
'   Bits [6..0]
'   6: One or more interrupts asserted
'   5: Z-axis transient interrupt
'   4: Z-axis transient interrupt polarity (0: positive, 1: negative)
'   3: Y-axis transient interrupt
'   2: Y-axis transient interrupt polarity (0: positive, 1: negative)
'   1: X-axis transient interrupt
'   0: X-axis transient interrupt polarity (0: positive, 1: negative)
    int_src := 0
    readreg(core#TRANSIENT_SRC, 1, @int_src)

PUB TransThresh(thr): curr_thr
' Set threshold for transient acceleration detection, in micro-g's
'   Valid values: 0..8_001000 (0..8gs)
'   Any other value polls the chip and returns the current setting
'   NOTE: If AccelPowerMode() == LOWNOISE, the maximum value is reduced
'       to 4g's (4_000000)
    curr_thr := 0
    readreg(core#TRANSIENT_THS, 1, @curr_thr)
    case thr
        0..8_001000:
            thr /= 0_063000
        other:
            return ((curr_thr & core#THS_BITS) * 0_063000)

    thr := ((curr_thr & core#THS_MASK) | thr)
    writereg(core#TRANSIENT_THS, 1, @thr)

PRI cacheOpMode{}
' Store the current operating mode, and switch to standby if different
'   (required for modifying some registers)
    _opmode_orig := accelopmode(-2)
    if _opmode_orig <> STDBY                    ' must be in standby to change
        accelopmode(STDBY)                      '   control regs

PRI restoreOpMode{}
' Restore original operating mode
    if _opmode_orig <> STDBY                    ' restore original opmode
        accelopmode(_opmode_orig)

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
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

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
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

