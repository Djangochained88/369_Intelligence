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
        return s;
    }

    function isMultipleOfThree(uint256 value) public pure returns (bool) {
        return value % T369_TRIAD_A == 0;
    }

    function isMultipleOfSix(uint256 value) public pure returns (bool) {
        return value % T369_TRIAD_B == 0;
    }

    function isMultipleOfNine(uint256 value) public pure returns (bool) {
        return value % T369_TRIAD_C == 0;
    }

    function triadReduction(uint256 value) public pure returns (uint256) {
        uint256 r = value % triadSum();
        return r;
    }

    function fluxCoefficient(uint256 a, uint256 b) public pure returns (uint256) {
        if (b == 0) revert T369_DivisionByZero();
        uint256 c = (a * T369_SCALE) / b;
        return c;
    }

    function harmonicTriad(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        if (a == 0 || b == 0 || c == 0) return 0;
        uint256 ab = a * b;
        uint256 bc = b * c;
        uint256 ac = a * c;
        if (ab / a != b || bc / b != c || ac / a != c) revert T369_ArithmeticOverflow();
        uint256 denom = ab + bc + ac;
        if (denom == 0) revert T369_DivisionByZero();
        uint256 num = tripleProduct(3, a, b);
        num = num * c;
        if (num / c != tripleProduct(3, a, b)) revert T369_ArithmeticOverflow();
        return num / denom;
    }

    function geometricTriadApprox(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        uint256 g1 = geometricMeanApprox(a, b);
        return geometricMeanApprox(g1, c);
    }

    function arithmeticTriad(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        uint256 s = a + b + c;
        if (s < a) revert T369_ArithmeticOverflow();
        return s / 3;
    }

    function quadraticResidue(uint256 a, uint256 p) public pure returns (uint256) {
        if (p == 0) revert T369_DivisionByZero();
        return (a * a) % p;
    }

    function cubicResidue(uint256 a, uint256 p) public pure returns (uint256) {
        if (p == 0) revert T369_DivisionByZero();
        uint256 a2 = (a * a) % p;
        return (a2 * a) % p;
    }

    function sumOfSquares(uint256 a, uint256 b) public pure returns (uint256) {
        uint256 a2 = a * a;
        uint256 b2 = b * b;
        if (a2 / a != a || b2 / b != b) revert T369_ArithmeticOverflow();
        uint256 s = a2 + b2;
        if (s < a2) revert T369_ArithmeticOverflow();
        return s;
    }

    function sumOfCubes(uint256 a, uint256 b) public pure returns (uint256) {
        uint256 a3 = a * a * a;
        uint256 b3 = b * b * b;
        if (a3 / a / a != a || b3 / b / b != b) revert T369_ArithmeticOverflow();
        uint256 s = a3 + b3;
        if (s < a3) revert T369_ArithmeticOverflow();
        return s;
    }

    function differenceOfSquares(uint256 a, uint256 b) public pure returns (uint256) {
        if (a < b) revert T369_ArithmeticOverflow();
        uint256 a2 = a * a;
        uint256 b2 = b * b;
        if (a2 / a != a || b2 / b != b) revert T369_ArithmeticOverflow();
        return a2 - b2;
    }

    function totientApprox(uint256 n) public pure returns (uint256) {
        if (n <= 1) return n;
        uint256 r = n;
        for (uint256 i = 2; i <= n && i <= 100; i++) {
            if (n % i == 0) {
                r = (r * (i - 1)) / i;
                while (n % i == 0) n /= i;
            }
        }
        return r;
    }

    function sigmaSum(uint256 n, uint256 k) public pure returns (uint256) {
        if (k > n) return 0;
        uint256 s = 0;
        for (uint256 i = k; i <= n; i++) {
            s += i;
            if (s < i) revert T369_ArithmeticOverflow();
        }
        return s;
    }

    function sigmaProduct(uint256 n, uint256 k) public pure returns (uint256) {
        if (k > n) return 0;
        uint256 p = 1;
        for (uint256 i = k; i <= n && i <= 20; i++) {
            p *= i;
            if (p / i != (i == k ? 1 : p)) revert T369_ArithmeticOverflow();
        }
        return p;
    }

    function triangularNumber(uint256 n) public pure returns (uint256) {
        if (n > type(uint256).max / 2) revert T369_ArithmeticOverflow();
        return (n * (n + 1)) / 2;
    }

    function isPerfectSquare(uint256 n) public pure returns (bool) {
        if (n == 0) return true;
        uint256 x = (n + 1) / 2;
        for (uint256 i = 0; i < 32; i++) {
            uint256 nx = (x + n / x) / 2;
            if (nx >= x) return x * x == n;
            x = nx;
        }
        return x * x == n;
    }

    function sqrtFloor(uint256 n) public pure returns (uint256) {
        if (n == 0) return 0;
        uint256 x = n;
        uint256 y = (x + 1) / 2;
        while (y < x) {
            x = y;
            y = (x + n / x) / 2;
        }
        return x;
    }

    function pow2(uint256 exp) public pure returns (uint256) {
        if (exp > 255) revert T369_ArithmeticOverflow();
        return 1 << exp;
    }

    function pow3(uint256 exp) public pure returns (uint256) {
        if (exp > 160) revert T369_ArithmeticOverflow();
        uint256 r = 1;
        uint256 b = 3;
        while (exp > 0) {
            if (exp & 1 != 0) {
                r = r * b;
                if (exp == 1) break;
            }
            b = b * b;
            exp >>= 1;
        }
        return r;
    }

    function modInverseApprox(uint256 a, uint256 m) public pure returns (uint256) {
        if (m == 0 || gcd(a, m) != 1) revert T369_DivisionByZero();
        return powMod(a, m - 2, m);
    }

    function binomialCoeff(uint256 n, uint256 k) public pure returns (uint256) {
        if (k > n) return 0;
        if (k == 0 || k == n) return 1;
        if (k > n - k) k = n - k;
        uint256 r = 1;
        for (uint256 i = 0; i < k; i++) {
            r = (r * (n - i)) / (i + 1);
        }
        return r;
    }

    function fibonacci(uint256 n) public pure returns (uint256) {
        if (n == 0) return 0;
        if (n <= 2) return 1;
        uint256 a = 1;
        uint256 b = 1;
        for (uint256 i = 3; i <= n && i <= 94; i++) {
            uint256 c = a + b;
            if (c < b) revert T369_ArithmeticOverflow();
            a = b;
            b = c;
        }
        return b;
    }

    function collatzStep(uint256 n) public pure returns (uint256) {
        if (n == 0) revert T369_ZeroMagnitude();
        if (n % 2 == 0) return n / 2;
        if (n > type(uint256).max / 3 - 1) revert T369_ArithmeticOverflow();
        return 3 * n + 1;
    }

    function digitCount(uint256 value) public pure returns (uint256) {
        if (value == 0) return 1;
        uint256 c = 0;
        while (value != 0) {
            c++;
            value /= 10;
        }
        return c;
    }

    function reverseDigits(uint256 value) public pure returns (uint256) {
        uint256 r = 0;
        while (value != 0) {
            r = r * 10 + (value % 10);
            value /= 10;
        }
        return r;
    }

    function isPalindrome(uint256 value) public pure returns (bool) {
        return value == reverseDigits(value);
    }

    function digitProduct(uint256 value) public pure returns (uint256) {
        if (value == 0) return 0;
        uint256 p = 1;
        while (value != 0) {
            p *= (value % 10);
            value /= 10;
        }
        return p;
    }

    function alternatingDigitSum(uint256 value) public pure returns (int256) {
        int256 sum = 0;
        int256 sign = 1;
        while (value != 0) {
            sum += sign * int256(int256(value % 10));
            sign = -sign;
            value /= 10;
        }
        return sum;
    }

    function min3(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        uint256 m = a;
        if (b < m) m = b;
        if (c < m) m = c;
        return m;
    }

    function max3(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        uint256 m = a;
        if (b > m) m = b;
        if (c > m) m = c;
        return m;
    }

    function median3(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        if (a > b) (a, b) = (b, a);
        if (b > c) (b, c) = (c, b);
        if (a > b) (a, b) = (b, a);
        return b;
    }

    function clamp(uint256 value, uint256 lo, uint256 hi) public pure returns (uint256) {
        if (value < lo) return lo;
        if (value > hi) return hi;
        return value;
    }

    function absDiff(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function percentOf(uint256 part, uint256 whole) public pure returns (uint256) {
        if (whole == 0) revert T369_DivisionByZero();
        return (part * 100) / whole;
    }

    function percentOfScaled(uint256 part, uint256 whole, uint256 scale) public pure returns (uint256) {
        if (whole == 0) revert T369_DivisionByZero();
        uint256 t = part * scale;
        if (t / part != scale) revert T369_ArithmeticOverflow();
        return t / whole;
    }

    function compoundFactor(uint256 ratePerUnit, uint256 periods) public pure returns (uint256) {
        uint256 r = 1e18;
        for (uint256 i = 0; i < periods && i < 100; i++) {
            r = (r * (1e18 + ratePerUnit)) / 1e18;
        }
        return r;
    }

    function linearInterpolate(uint256 x0, uint256 y0, uint256 x1, uint256 y1, uint256 x) public pure returns (uint256) {
        if (x1 == x0) return y0;
        uint256 dx = x1 - x0;
        uint256 t = x - x0;
        if (y1 >= y0) {
            uint256 dy = y1 - y0;
            uint256 num = t * dy;
            if (dy != 0 && num / dy != t) revert T369_ArithmeticOverflow();
            return y0 + num / dx;
        } else {
            uint256 dy = y0 - y1;
            uint256 num = t * dy;
            if (dy != 0 && num / dy != t) revert T369_ArithmeticOverflow();
            return y0 - num / dx;
        }
    }

    function weightedAverage(uint256[] calldata values, uint256[] calldata weights) public pure returns (uint256) {
        if (values.length != weights.length || values.length == 0) revert T369_ArrayLengthMismatch();
        uint256 sumW = 0;
        uint256 sumVW = 0;
        for (uint256 i = 0; i < values.length; i++) {
            sumW += weights[i];
            uint256 vw = values[i] * weights[i];
            if (vw / values[i] != weights[i]) revert T369_ArithmeticOverflow();
            sumVW += vw;
        }
        if (sumW == 0) revert T369_DivisionByZero();
        return sumVW / sumW;
    }

    function varianceApprox(uint256[] calldata arr) public pure returns (uint256) {
        if (arr.length == 0) revert T369_EmptyOperands();
        uint256 s = sumArray(arr);
        uint256 mean = s / arr.length;
        uint256 varSum = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            uint256 d = arr[i] > mean ? arr[i] - mean : mean - arr[i];
            varSum += d * d;
        }
        return varSum / arr.length;
    }

    function minArray(uint256[] calldata arr) public pure returns (uint256) {
        if (arr.length == 0) revert T369_EmptyOperands();
        uint256 m = arr[0];
        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] < m) m = arr[i];
        }
        return m;
    }

    function maxArray(uint256[] calldata arr) public pure returns (uint256) {
        if (arr.length == 0) revert T369_EmptyOperands();
        uint256 m = arr[0];
        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] > m) m = arr[i];
        }
        return m;
    }

    function rangeArray(uint256[] calldata arr) public pure returns (uint256 minVal, uint256 maxVal) {
        if (arr.length == 0) revert T369_EmptyOperands();
        minVal = arr[0];
        maxVal = arr[0];
        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] < minVal) minVal = arr[i];
            if (arr[i] > maxVal) maxVal = arr[i];
        }
    }

    function countTriadResonantInArray(uint256[] calldata arr) public pure returns (uint256) {
        uint256 c = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            if (isTriadResonant(arr[i])) c++;
        }
        return c;
    }

    function sumDigitsBatch(uint256[] calldata values) public pure returns (uint256[] memory sums) {
        sums = new uint256[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            sums[i] = digitSum(values[i]);
        }
    }

    function digitalRootBatch(uint256[] calldata values) public pure returns (uint256[] memory roots) {
        roots = new uint256[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            roots[i] = digitalRoot(values[i]);
        }
    }

    function scaledBatch(uint256[] calldata values, uint256 scale) public pure returns (uint256[] memory out) {
        out = new uint256[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            uint256 t = values[i] * scale;
            if (scale != 0 && t / values[i] != scale) revert T369_ArithmeticOverflow();
            out[i] = t;
        }
    }

    function mulDivBatch(uint256[] calldata a, uint256[] calldata b, uint256[] calldata denom) public pure returns (uint256[] memory out) {
        if (a.length != b.length || b.length != denom.length) revert T369_ArrayLengthMismatch();
        out = new uint256[](a.length);
        for (uint256 i = 0; i < a.length; i++) {
            out[i] = mulDiv(a[i], b[i], denom[i]);
        }
    }

    function gcdBatch(uint256[] calldata values) public pure returns (uint256) {
        if (values.length == 0) revert T369_EmptyOperands();
        uint256 g = values[0];
        for (uint256 i = 1; i < values.length; i++) {
            g = gcd(g, values[i]);
        }
        return g;
    }

    function lcmBatch(uint256[] calldata values) public pure returns (uint256) {
        if (values.length == 0) revert T369_EmptyOperands();
        uint256 l = values[0];
        for (uint256 i = 1; i < values.length; i++) {
            l = lcm(l, values[i]);
        }
        return l;
    }

    function factorialBatch(uint256[] calldata ns) public pure returns (uint256[] memory out) {
        out = new uint256[](ns.length);
        for (uint256 i = 0; i < ns.length; i++) {
            out[i] = factorial(ns[i]);
        }
    }

    function triangularBatch(uint256[] calldata ns) public pure returns (uint256[] memory out) {
        out = new uint256[](ns.length);
        for (uint256 i = 0; i < ns.length; i++) {
            out[i] = triangularNumber(ns[i]);
        }
    }

    function fluxHash(bytes32 seed) public view returns (bytes32) {
        return keccak256(abi.encodePacked(seed, block.timestamp, block.prevrandao, currentPhase, magnitudeBound));
    }

    function resonanceScore(uint256 value) public pure returns (uint256) {
        uint256 dr = digitalRoot(value);
        uint256 m = mod369(value);
        uint256 ds = digitSum(value);
        return dr * T369_BASE + m + ds;
    }

    function triadAlignment(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        if (!verifyTriad(a, b, c)) return 0;
        return (a + b + c) / T369_TRIAD_A;
    }

    function magnitudePhaseEncode(uint256 magnitude, uint256 phase) public pure returns (uint256) {
        if (phase >= T369_SCALE) revert T369_PhaseOutOfRange();
        if (magnitude > type(uint256).max / T369_SCALE) revert T369_ArithmeticOverflow();
        return magnitude * T369_SCALE + phase;
    }

    function magnitudePhaseDecode(uint256 encoded) public pure returns (uint256 magnitude, uint256 phase) {
        magnitude = encoded / T369_SCALE;
        phase = encoded % T369_SCALE;
    }

    // -------------------------------------------------------------------------
    // EXTENDED SUPER CALCULATOR (pure)
    // -------------------------------------------------------------------------

    function add3(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        uint256 s = a + b;
        if (s < a) revert T369_ArithmeticOverflow();
        s += c;
        if (s < c) revert T369_ArithmeticOverflow();
        return s;
    }

    function add4(uint256 a, uint256 b, uint256 c, uint256 d) public pure returns (uint256) {
        uint256 s = add3(a, b, c);
        s += d;
        if (s < d) revert T369_ArithmeticOverflow();
        return s;
    }

    function subSafe(uint256 a, uint256 b) public pure returns (uint256) {
        if (b > a) revert T369_ArithmeticOverflow();
        return a - b;
    }

    function mulSafe(uint256 a, uint256 b) public pure returns (uint256) {
        uint256 p = a * b;
        if (b != 0 && p / b != a) revert T369_ArithmeticOverflow();
        return p;
    }

    function divCeil(uint256 a, uint256 b) public pure returns (uint256) {
        if (b == 0) revert T369_DivisionByZero();
        return (a + b - 1) / b;
    }

    function modSafe(uint256 a, uint256 b) public pure returns (uint256) {
        if (b == 0) revert T369_DivisionByZero();
        return a % b;
    }

    function exp2(uint256 n) public pure returns (uint256) {
        if (n > 255) revert T369_ArithmeticOverflow();
        return 1 << n;
    }

    function log2Floor(uint256 n) public pure returns (uint256) {
        if (n == 0) revert T369_ZeroMagnitude();
        uint256 r = 0;
        while (n > 1) {
            n >>= 1;
            r++;
        }
        return r;
    }

    function isPowerOfTwo(uint256 n) public pure returns (bool) {
        return n != 0 && (n & (n - 1)) == 0;
    }

    function nextPowerOfTwo(uint256 n) public pure returns (uint256) {
        if (n == 0) return 1;
        n--;
        n |= n >> 1;
        n |= n >> 2;
        n |= n >> 4;
        n |= n >> 8;
        n |= n >> 16;
        n |= n >> 32;
        n |= n >> 64;
        n |= n >> 128;
        return n + 1;
    }

    function bitCount(uint256 n) public pure returns (uint256) {
        uint256 c = 0;
        while (n != 0) {
            c += n & 1;
            n >>= 1;
        }
        return c;
    }

    function parity(uint256 n) public pure returns (uint256) {
        return bitCount(n) % 2;
    }

    function rotateLeft(uint256 n, uint256 k) public pure returns (uint256) {
        k = k % 256;
        return (n << k) | (n >> (256 - k));
    }

    function rotateRight(uint256 n, uint256 k) public pure returns (uint256) {
        k = k % 256;
        return (n >> k) | (n << (256 - k));
    }

    function xorAll(uint256[] calldata arr) public pure returns (uint256) {
        if (arr.length == 0) revert T369_EmptyOperands();
        uint256 r = arr[0];
        for (uint256 i = 1; i < arr.length; i++) {
            r ^= arr[i];
        }
        return r;
    }

    function andAll(uint256[] calldata arr) public pure returns (uint256) {
        if (arr.length == 0) revert T369_EmptyOperands();
        uint256 r = type(uint256).max;
        for (uint256 i = 0; i < arr.length; i++) {
            r &= arr[i];
        }
        return r;
    }

    function orAll(uint256[] calldata arr) public pure returns (uint256) {
        if (arr.length == 0) revert T369_EmptyOperands();
        uint256 r = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            r |= arr[i];
        }
        return r;
    }

    function sumOfPowers(uint256 base, uint256 n) public pure returns (uint256) {
        if (base == 0) return 0;
        if (base == 1) return n + 1;
        uint256 s = 0;
        uint256 term = 1;
        for (uint256 i = 0; i <= n && i < 50; i++) {
            s += term;
            term = term * base;
            if (term / base != (i == 0 ? 1 : term)) revert T369_ArithmeticOverflow();
        }
        return s;
    }

    function polyEval(uint256[] calldata coeffs, uint256 x) public pure returns (uint256) {
        if (coeffs.length == 0) revert T369_EmptyOperands();
        uint256 r = coeffs[coeffs.length - 1];
        for (uint256 i = coeffs.length - 1; i > 0;) {
            unchecked { i--; }
            r = r * x + coeffs[i];
        }
        return r;
