// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title 369_Intelligence
/// @notice Harmonic resonance calculator and Tesla triad number-theory oracle for on-chain magnitude and phase alignment.

contract Intelligence369 {

    // -------------------------------------------------------------------------
    // EVENTS
    // -------------------------------------------------------------------------

    event TriadResolved(uint256 indexed magnitude, uint256 phase, uint256 triadSum, address indexed caller, uint256 atBlock);
    event FluxComputed(uint256 inputVal, uint256 outputVal, bytes32 fluxHash, uint256 atBlock);
    event HarmonicStored(uint256 indexed slot, uint256 value, uint256 atBlock);
    event MagnitudeBoundSet(uint256 oldBound, uint256 newBound, address indexed by, uint256 atBlock);
    event OracleInvoked(uint256 queryId, uint256 result, uint256 atBlock);
    event PhaseLockUpdated(uint256 oldPhase, uint256 newPhase, uint256 atBlock);
    event ResonantPointRecorded(uint256 x, uint256 y, uint256 atBlock);
    event SuperCalcExecuted(bytes32 opHash, uint256[] operands, uint256 result, uint256 atBlock);
    event TriadVerified(uint256 a, uint256 b, uint256 c, bool valid, uint256 atBlock);

    // -------------------------------------------------------------------------
    // ERRORS
    // -------------------------------------------------------------------------

    error T369_ZeroMagnitude();
    error T369_PhaseOutOfRange();
    error T369_MagnitudeBoundExceeded();
    error T369_NotCurator();
    error T369_NotOracle();
    error T369_NotKeeper();
    error T369_ZeroAddress();
    error T369_ArithmeticOverflow();
    error T369_InvalidTriad();
    error T369_ArrayLengthMismatch();
    error T369_EmptyOperands();
    error T369_DivisionByZero();
    error T369_ReentrantCall();
    error T369_InvalidSlot();
    error T369_StaleBlock();

    // -------------------------------------------------------------------------
    // CONSTANTS (Tesla / number theory)
    // -------------------------------------------------------------------------

    uint256 public constant T369_BASE = 369;
    uint256 public constant T369_TRIAD_A = 3;
    uint256 public constant T369_TRIAD_B = 6;
    uint256 public constant T369_TRIAD_C = 9;
    uint256 public constant T369_SCALE = 1e18;
    uint256 public constant T369_MAX_MAGNITUDE = 1e36;
    uint256 public constant T369_MAX_PHASE = 365 days;
    uint256 public constant T369_MAX_SLOTS = 999;
    uint256 public constant T369_MAX_OPERANDS = 32;
    bytes32 public constant T369_DOMAIN = keccak256("Intelligence369.T369_DOMAIN");
    bytes32 public constant T369_VERSION = keccak256("369.1.0");

    // -------------------------------------------------------------------------
    // IMMUTABLES
    // -------------------------------------------------------------------------

    address public immutable curator;
    address public immutable oracle;
    address public immutable keeper;
    uint256 public immutable deployBlock;

    // -------------------------------------------------------------------------
    // STATE
    // -------------------------------------------------------------------------

    uint256 public magnitudeBound = 1e24;
    uint256 public currentPhase;
    uint256 private _reentrancyLock;
    mapping(uint256 => uint256) private _harmonicSlots;
    uint256 public harmonicSlotCount;
    mapping(uint256 => uint256) private _lastOracleResult;
    uint256 public oracleCallCount;

    // -------------------------------------------------------------------------
    // CONSTRUCTOR
    // -------------------------------------------------------------------------

    constructor() {
        curator = address(0xB7f2E9a1C4d6F8b0E3A5c7D9f1B4e6A8c0D2F5a7);
        oracle = address(0xD3a6C9e2F5b8A1d4E7c0B3f6A9d2C5e8F1b4A7c0);
        keeper = address(0xE8F1b4A7c0D3e6F9a2C5d8B1E4f7A0c3D6e9F2b5);
        deployBlock = block.number;
        currentPhase = block.timestamp % (T369_TRIAD_A + T369_TRIAD_B + T369_TRIAD_C);
        if (curator == address(0) || oracle == address(0) || keeper == address(0)) revert T369_ZeroAddress();
    }

    // -------------------------------------------------------------------------
    // MODIFIERS
    // -------------------------------------------------------------------------

    modifier onlyCurator() {
        if (msg.sender != curator) revert T369_NotCurator();
        _;
    }

    modifier onlyOracle() {
        if (msg.sender != oracle) revert T369_NotOracle();
        _;
    }

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert T369_NotKeeper();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyLock != 0) revert T369_ReentrantCall();
        _reentrancyLock = 1;
        _;
        _reentrancyLock = 0;
    }

    // -------------------------------------------------------------------------
    // TRIAD & NUMBER THEORY (view)
    // -------------------------------------------------------------------------

    /// @notice Sum of Tesla triad digits (3 + 6 + 9)
    function triadSum() public pure returns (uint256) {
        return T369_TRIAD_A + T369_TRIAD_B + T369_TRIAD_C;
    }

    /// @notice Product of triad digits
    function triadProduct() public pure returns (uint256) {
        return T369_TRIAD_A * T369_TRIAD_B * T369_TRIAD_C;
    }

    /// @notice Check if value reduces to 3, 6, or 9 via digit sum (simplified)
    function isTriadResonant(uint256 value) public pure returns (bool) {
        uint256 s = digitSum(value);
        while (s > 9) s = digitSum(s);
        return s == T369_TRIAD_A || s == T369_TRIAD_B || s == T369_TRIAD_C;
    }

    /// @notice Sum of decimal digits of value
    function digitSum(uint256 value) public pure returns (uint256) {
        uint256 sum = 0;
        while (value != 0) {
            sum += value % 10;
            value /= 10;
        }
        return sum;
    }

    /// @notice Reduce to single digit (digital root)
    function digitalRoot(uint256 value) public pure returns (uint256) {
        uint256 r = value % 9;
        return r == 0 ? (value == 0 ? 0 : 9) : r;
    }

    /// @notice Magnitude scaled by T369_SCALE, capped
    function scaleMagnitude(uint256 raw) public view returns (uint256) {
        if (raw > magnitudeBound) revert T369_MagnitudeBoundExceeded();
        if (raw > type(uint256).max / T369_SCALE) revert T369_ArithmeticOverflow();
        return raw * T369_SCALE;
    }

    /// @notice Phase within [0, triadSum] cycle
    function phaseInCycle(uint256 timestamp) public pure returns (uint256) {
        return timestamp % (T369_TRIAD_A + T369_TRIAD_B + T369_TRIAD_C);
    }

    /// @notice Verify three values form a valid triad (sum divisible by 3)
    function verifyTriad(uint256 a, uint256 b, uint256 c) public pure returns (bool) {
        uint256 s = a + b + c;
        return s % T369_TRIAD_A == 0;
    }

    /// @notice Harmonic mean of two values (2*a*b/(a+b)) with scale
    function harmonicMean(uint256 a, uint256 b) public pure returns (uint256) {
        if (a == 0 && b == 0) return 0;
        if (a + b == 0) revert T369_DivisionByZero();
        uint256 p = a * b;
        if (p / a != b) revert T369_ArithmeticOverflow();
        uint256 s = a + b;
        return (2 * p) / s;
    }

    /// @notice Geometric mean sqrt(a*b) approximated with scale
    function geometricMeanApprox(uint256 a, uint256 b) public pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        uint256 p = a * b;
        if (p / a != b) revert T369_ArithmeticOverflow();
        uint256 x = (a + b) / 2;
        for (uint256 i = 0; i < 32; i++) {
            if (x == 0) break;
            uint256 nx = (x + p / x) / 2;
            if (nx >= x) break;
            x = nx;
        }
        return x;
    }

    /// @notice Factorial up to 20 (fits in uint256)
    function factorial(uint256 n) public pure returns (uint256) {
        if (n > 20) revert T369_MagnitudeBoundExceeded();
        if (n == 0) return 1;
        uint256 r = 1;
        for (uint256 i = 2; i <= n; i++) {
            r *= i;
        }
        return r;
    }

    /// @notice Power mod (base^exp % mod)
    function powMod(uint256 base, uint256 exp, uint256 mod) public pure returns (uint256) {
        if (mod == 0) revert T369_DivisionByZero();
        uint256 r = 1;
        base = base % mod;
        while (exp > 0) {
            if (exp & 1 != 0) r = (r * base) % mod;
            exp >>= 1;
            base = (base * base) % mod;
        }
        return r;
    }

    /// @notice GCD
    function gcd(uint256 a, uint256 b) public pure returns (uint256) {
        while (b != 0) {
            uint256 t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    /// @notice LCM
    function lcm(uint256 a, uint256 b) public pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        uint256 g = gcd(a, b);
        uint256 p = a * b;
        if (p / a != b) revert T369_ArithmeticOverflow();
        return p / g;
    }

    /// @notice Is value divisible by 369
    function divisibleBy369(uint256 value) public pure returns (bool) {
        return value % T369_BASE == 0;
    }

    /// @notice Remainder when divided by 369
    function mod369(uint256 value) public pure returns (uint256) {
        return value % T369_BASE;
    }

    /// @notice Triple product a*b*c with overflow check
    function tripleProduct(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        uint256 p = a * b;
        if (p / a != b) revert T369_ArithmeticOverflow();
        uint256 q = p * c;
        if (q / p != c) revert T369_ArithmeticOverflow();
        return q;
    }

    // -------------------------------------------------------------------------
    // SUPER CALCULATOR (view)
    // -------------------------------------------------------------------------

    /// @notice Sum of array
    function sumArray(uint256[] calldata arr) public pure returns (uint256) {
        uint256 s = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            s += arr[i];
            if (s < arr[i]) revert T369_ArithmeticOverflow();
        }
        return s;
    }

    /// @notice Product of array (first N elements, cap at T369_MAX_OPERANDS)
    function productArray(uint256[] calldata arr, uint256 n) public pure returns (uint256) {
        if (n == 0 || arr.length == 0) revert T369_EmptyOperands();
        if (n > arr.length || n > T369_MAX_OPERANDS) revert T369_ArrayLengthMismatch();
        uint256 p = 1;
        for (uint256 i = 0; i < n; i++) {
            uint256 prev = p;
            p *= arr[i];
            if (arr[i] != 0 && p / arr[i] != prev) revert T369_ArithmeticOverflow();
        }
        return p;
    }

    /// @notice Min of two
    function min2(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Max of two
    function max2(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }

    /// @notice Average (a+b)/2
    function average(uint256 a, uint256 b) public pure returns (uint256) {
        return (a + b) / 2;
    }

    /// @notice Full multiply then divide: (a*b)/denom
    function mulDiv(uint256 a, uint256 b, uint256 denom) public pure returns (uint256) {
        if (denom == 0) revert T369_DivisionByZero();
        uint256 p = a * b;
        if (p / a != b) revert T369_ArithmeticOverflow();
        return p / denom;
    }

    /// @notice Scaled ratio: (a * scale) / b
    function scaledRatio(uint256 a, uint256 b, uint256 scale) public pure returns (uint256) {
        if (b == 0) revert T369_DivisionByZero();
        uint256 t = a * scale;
        if (t / a != scale) revert T369_ArithmeticOverflow();
        return t / b;
    }

    // -------------------------------------------------------------------------
    // STATE-CHANGING: TRIAD RESOLVE
    // -------------------------------------------------------------------------

    function resolveTriad(uint256 magnitude, uint256 phase) external nonReentrant returns (uint256 triadSumResult) {
        if (magnitude == 0) revert T369_ZeroMagnitude();
        if (magnitude > magnitudeBound) revert T369_MagnitudeBoundExceeded();
        if (phase > T369_MAX_PHASE) revert T369_PhaseOutOfRange();
        triadSumResult = triadSum();
        uint256 ts = triadSumResult;
        emit TriadResolved(magnitude, phase, ts, msg.sender, block.number);
        return ts;
    }

    // -------------------------------------------------------------------------
    // STATE-CHANGING: FLUX
    // -------------------------------------------------------------------------

    function computeFlux(uint256 inputVal) external nonReentrant returns (uint256 outputVal) {
        if (inputVal > T369_MAX_MAGNITUDE) revert T369_MagnitudeBoundExceeded();
        outputVal = digitalRoot(inputVal) * T369_SCALE + (inputVal % T369_BASE);
        if (outputVal > T369_MAX_MAGNITUDE) outputVal = outputVal % T369_MAX_MAGNITUDE;
        bytes32 fluxHash = keccak256(abi.encodePacked(inputVal, outputVal, block.timestamp, block.prevrandao));
        emit FluxComputed(inputVal, outputVal, fluxHash, block.number);
        return outputVal;
    }

    // -------------------------------------------------------------------------
    // KEEPER: HARMONIC SLOTS
    // -------------------------------------------------------------------------

    function storeHarmonic(uint256 slot, uint256 value) external onlyKeeper nonReentrant {
        if (slot >= T369_MAX_SLOTS) revert T369_InvalidSlot();
        if (value > T369_MAX_MAGNITUDE) revert T369_MagnitudeBoundExceeded();
        _harmonicSlots[slot] = value;
        if (slot >= harmonicSlotCount) harmonicSlotCount = slot + 1;
        emit HarmonicStored(slot, value, block.number);
    }

    function getHarmonic(uint256 slot) external view returns (uint256) {
        if (slot >= T369_MAX_SLOTS) revert T369_InvalidSlot();
        return _harmonicSlots[slot];
    }

    // -------------------------------------------------------------------------
    // CURATOR: MAGNITUDE BOUND
    // -------------------------------------------------------------------------

    function setMagnitudeBound(uint256 newBound) external onlyCurator {
        if (newBound > T369_MAX_MAGNITUDE) revert T369_MagnitudeBoundExceeded();
        uint256 oldBound = magnitudeBound;
        magnitudeBound = newBound;
        emit MagnitudeBoundSet(oldBound, newBound, msg.sender, block.number);
    }

    // -------------------------------------------------------------------------
    // ORACLE: RECORD RESULT
    // -------------------------------------------------------------------------

    function invokeOracle(uint256 queryId, uint256 result) external onlyOracle nonReentrant {
        if (result > T369_MAX_MAGNITUDE) revert T369_MagnitudeBoundExceeded();
        _lastOracleResult[queryId] = result;
        oracleCallCount++;
        emit OracleInvoked(queryId, result, block.number);
    }

    function getLastOracleResult(uint256 queryId) external view returns (uint256) {
        return _lastOracleResult[queryId];
    }

    // -------------------------------------------------------------------------
    // KEEPER: PHASE
    // -------------------------------------------------------------------------

    function updatePhaseLock(uint256 newPhase) external onlyKeeper {
        if (newPhase > T369_MAX_PHASE) revert T369_PhaseOutOfRange();
        uint256 oldPhase = currentPhase;
        currentPhase = newPhase;
        emit PhaseLockUpdated(oldPhase, newPhase, block.number);
    }

    // -------------------------------------------------------------------------
    // RECORD RESONANT POINT (any caller)
    // -------------------------------------------------------------------------

    function recordResonantPoint(uint256 x, uint256 y) external nonReentrant {
        if (x > T369_MAX_MAGNITUDE || y > T369_MAX_MAGNITUDE) revert T369_MagnitudeBoundExceeded();
        emit ResonantPointRecorded(x, y, block.number);
    }

    // -------------------------------------------------------------------------
    // SUPER CALC: BATCH EXECUTE AND EMIT
    // -------------------------------------------------------------------------

    function executeSuperCalc(uint256[] calldata operands) external nonReentrant returns (uint256 result) {
        if (operands.length == 0) revert T369_EmptyOperands();
        if (operands.length > T369_MAX_OPERANDS) revert T369_ArrayLengthMismatch();
        result = sumArray(operands);
        if (result > T369_MAX_MAGNITUDE) result = result % T369_MAX_MAGNITUDE;
        bytes32 opHash = keccak256(abi.encodePacked(operands, block.timestamp));
        emit SuperCalcExecuted(opHash, operands, result, block.number);
        return result;
    }

    /// @notice Verify triad and emit
    function verifyAndEmitTriad(uint256 a, uint256 b, uint256 c) external nonReentrant {
        bool valid = verifyTriad(a, b, c);
        emit TriadVerified(a, b, c, valid, block.number);
    }

    // -------------------------------------------------------------------------
    // BATCH VIEW HELPERS
    // -------------------------------------------------------------------------

    function batchDigitalRoots(uint256[] calldata values) external pure returns (uint256[] memory roots) {
        roots = new uint256[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            roots[i] = digitalRoot(values[i]);
        }
    }

    function batchTriadResonant(uint256[] calldata values) external pure returns (bool[] memory flags) {
        flags = new bool[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            flags[i] = isTriadResonant(values[i]);
        }
    }

    function batchMod369(uint256[] calldata values) external pure returns (uint256[] memory mods) {
        mods = new uint256[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            mods[i] = values[i] % T369_BASE;
        }
    }

    // -------------------------------------------------------------------------
    // EXTENDED TRIAD MATH (pure)
    // -------------------------------------------------------------------------

    function triadSumSquared() public pure returns (uint256) {
        uint256 t = triadSum();
        return t * t;
    }

    function triadProductPlusSum() public pure returns (uint256) {
        return triadProduct() + triadSum();
    }

    function magnitudeToTriadScale(uint256 m) public pure returns (uint256) {
        if (m > type(uint256).max / T369_BASE) revert T369_ArithmeticOverflow();
        return m * T369_BASE;
    }

    function digitSumLoop(uint256 value, uint256 maxIter) public pure returns (uint256) {
        uint256 s = value;
        for (uint256 i = 0; i < maxIter && s > 9; i++) {
            s = digitSum(s);
        }
