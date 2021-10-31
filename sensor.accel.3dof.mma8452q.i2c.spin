{
    --------------------------------------------
    Filename: sensor.accel.3dof.mma8452q.i2c.spin
    Author: Jesse Burt
    Description: Driver for the MMA8452Q 3DoF accelerometer
    Copyright (c) 2021
    Started May 09, 2021
    Updated Aug 8, 2021
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

VAR

    long _ares
    long _abiasraw[ACCEL_DOF]

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
    reset{}
    accelopmode(ACTIVE)
    accelscale(2)

PUB Preset_ClickDet{}
' Preset for click detection
    reset{}
    accelopmode(STDBY)
    acceldatarate(400)
    accelscale(2)
    clickaxisenabled(%010101)                   ' enable X, Y, Z single tap det
    clickthreshx(1_575000)                      ' X: 1.575g thresh
    clickthreshy(1_575000)                      ' Y: 1.575g
    clickthreshz(2_650000)                      ' Z: 2.650g
    clicktime(80)
    clicklatency(240)
    intmask(INT_PULSE)                          ' enable click/pulse interrupts
    introuting(INT_PULSE)                       ' route click ints to INT1 pin
    accelopmode(ACTIVE)

PUB AccelADCRes(adc_res): curr_res
' dummy method

PUB AccelAxisEnabled(xyz_mask): curr_mask
' dummy method

PUB AccelBias(bias_x, bias_y, bias_z, rw) | tmp, opmode_orig
' Read or write/manually set accelerometer calibration offset values
'   Valid values:
'       rw:
'           R (0), W (1)
'       bias_x, bias_y, bias_z:
'           -128..127
'   NOTE: When rw is set to READ, bias_x, bias_y and bias_z must be pointers
'       to respective variables to hold the returned calibration offset values
    tmp := opmode_orig := 0
    case rw
        R:
            readreg(core#OFF_X, 3, @tmp)
            _abiasraw[X_AXIS] := long[bias_x] := ~tmp.byte[X_AXIS]
            _abiasraw[Y_AXIS] := long[bias_y] := ~tmp.byte[Y_AXIS]
            _abiasraw[Z_AXIS] := long[bias_z] := ~tmp.byte[Z_AXIS]
            return
        W:
            case bias_x
                -128..127:
                    _abiasraw[X_AXIS] := bias_x
                other:
                    return
            case bias_y
                -128..127:
                    _abiasraw[Y_AXIS] := bias_y
                other:
                    return
            case bias_z
                -128..127:
                    _abiasraw[Z_AXIS] := bias_z
                other:
                    return
            opmode_orig := accelopmode(-2)
            if opmode_orig <> STDBY
                accelopmode(STDBY)

            writereg(core#OFF_X, 1, @_abiasraw[X_AXIS])
            writereg(core#OFF_Y, 1, @_abiasraw[Y_AXIS])
            writereg(core#OFF_Z, 1, @_abiasraw[Z_AXIS])

            if opmode_orig <> STDBY
                accelopmode(opmode_orig)

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

PUB AccelLowNoiseMode(mode): curr_mode | opmode_orig    'XXX tentatively named
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

    opmode_orig := accelopmode(-2)

    if opmode_orig <> STDBY
        accelopmode(STDBY)

    mode := ((curr_mode & core#LNOISE_MASK) | mode)
    writereg(core#CTRL_REG1, 1, @mode)

    if opmode_orig <> STDBY
        accelopmode(opmode_orig)

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

PUB AccelPowerMode(mode): curr_mode | opmode_orig ' XXX tentatively named
' Set accelerometer power mode/oversampling mode
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

    opmode_orig := accelopmode(-2)

    if opmode_orig <> STDBY
        accelopmode(STDBY)

    writereg(core#CTRL_REG2, 1, @mode)

    if opmode_orig <> STDBY
        accelopmode(opmode_orig)

PUB AccelScale(scale): curr_scl | opmode_orig
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
    opmode_orig := accelopmode(-2)
    accelopmode(STDBY)                          ' must be in standby to change

    writereg(core#XYZ_DATA_CFG, 1, @scale)

    if opmode_orig == ACTIVE                    ' restore opmode, if applicable
        accelopmode(ACTIVE)

PUB CalibrateAccel{} | acceltmp[ACCEL_DOF], axis, x, y, z, samples, scale_orig, drate_orig
' Calibrate the accelerometer
    longfill(@acceltmp, 0, 10)                  ' init variables to 0
    drate_orig := acceldatarate(-2)             ' store user-set data rate
    scale_orig := accelscale(-2)                '   and scale

    accelbias(0, 0, 0, W)                       ' clear existing bias offsets

    acceldatarate(CAL_XL_DR)                    ' set data rate and scale to
    accelscale(CAL_XL_SCL)                      '   device-specific settings
    samples := CAL_XL_DR                        ' samples = DR for approx 1sec
                                                '   worth of data
    repeat samples
        repeat until acceldataready{}
        acceldata(@x, @y, @z)                   ' throw out first set of samples

    repeat samples
        repeat until acceldataready{}
        acceldata(@x, @y, @z)                   ' accumulate samples to be
        acceltmp[X_AXIS] -= x                   '   averaged
        acceltmp[Y_AXIS] -= y
        acceltmp[Z_AXIS] -= z - (1_000_000 / _ares)

    ' write the updated offsets
    accelbias(acceltmp[X_AXIS] / samples, acceltmp[Y_AXIS] / samples, {
}   acceltmp[Z_AXIS] / samples, W)

    acceldatarate(drate_orig)                   ' restore user settings
    accelscale(scale_orig)

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

pUB Clicked{}: flag
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

PUB ClickLatency(ltime): curr_ltime
'   Set minimum elapsed time from detection of first click to recognition of
'       any subsequent clicks (single or double). All clicks *during* this time
'       will be ignored.
'   Valid values:
'           XXX TBD
'   Any other value polls the chip and returns the current setting
'   NOTE: Minimum unit is dependent on the current output data rate (AccelDataRate)
    case ltime
        0..255: ' XXX rewrite with time units
            writereg(core#PULSE_LTCY, 1, @ltime)
        other:
            return curr_ltime

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
'       AccelDataRate():    Max time range:
'       800                 159_000
'       400                 159_000
'       200                 319_000
'       100                 638_000
'       50                  1_280_000
'       12                  1_280_000
'       6                   1_280_000
'       1                   1_280_000
'   Any other value polls the chip and returns the current setting
    ' calc time resolution (in microseconds) based on AccelDataRate() (1/ODR),
    '   then limit to range spec'd in AN4072
    odr := acceldatarate(-2)
    time_res := 0_625 #> ((1_000000/odr) / 4) <# 5_000

    ' check that the parameter is between 0 and the max time range for
    '   the current AccelDataRate() setting
    if (ctime => 0) and (ctime =< (time_res * 255))
        ctime /= time_res
        writereg(core#PULSE_TMLT, 1, @ctime)
    else
        readreg(core#PULSE_TMLT, 1, @curr_ctime)
        return (curr_ctime * time_res)

PUB DoubleClickWindow(dctime): curr_dctime | time_res
' Set maximum elapsed interval between two consecutive clicks, in uSec
'   Valid values:
'       XXX TBD
'   Any other value polls the chip and returns the current setting
    case dctime
        0..255:
            writereg(core#PULSE_WIND, 1, @dctime)
        other:
            curr_dctime := 0
            readreg(core#PULSE_WIND, 1, @curr_dctime)

PUB DeviceID{}: id
' Read device identification
'   Returns: $2A
    readreg(core#WHO_AM_I, 1, @id)

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

PUB IntMask(mask): curr_mask | opmode_orig
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
            opmode_orig := accelopmode(-2)
            if opmode_orig <> STDBY
                accelopmode(STDBY)

            writereg(core#CTRL_REG4, 1, @mask)

            if opmode_orig <> STDBY
                accelopmode(opmode_orig)
        other:
            readreg(core#CTRL_REG4, 1, @curr_mask)
            return

PUB IntRouting(mask): curr_mask | opmode_orig
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
            opmode_orig := accelopmode(-2)
            if opmode_orig <> STDBY
                accelopmode(STDBY)

            writereg(core#CTRL_REG5, 1, @mask)

            if opmode_orig <> STDBY
                accelopmode(opmode_orig)
        other:
            readreg(core#CTRL_REG5, 1, @curr_mask)
            return

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
    accelopmode(STDBY)
    writereg(core#PL_CFG, 1, @state)
    accelopmode(ACTIVE)

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
