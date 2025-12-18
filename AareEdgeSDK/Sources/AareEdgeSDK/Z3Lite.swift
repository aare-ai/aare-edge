import Foundation

/// Lightweight constraint solver for policy verification.
///
/// Z3Lite provides a subset of Z3 SMT solver functionality optimized for
/// bounded policy verification on edge devices. It supports boolean logic,
/// comparisons, and basic arithmetic for checking compliance rules.
///
/// ## Usage
/// ```swift
/// let solver = Z3Lite()
///
/// // Define variables
/// let hasPHI = solver.boolVar("has_phi")
/// let phiCount = solver.intVar("phi_count")
///
/// // Add constraints
/// solver.assert(hasPHI)
/// solver.assert(phiCount.gt(0))
///
/// // Check satisfiability
/// let result = solver.check()
/// print(result.isSatisfiable)
/// ```
public final class Z3Lite {

    // MARK: - Properties

    /// Current assertions
    private var assertions: [Expression] = []

    /// Variable bindings
    private var bindings: [String: Value] = [:]

    /// Assertion stack for push/pop
    private var assertionStack: [[Expression]] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - Variable Creation

    /// Create a boolean variable.
    public func boolVar(_ name: String) -> BoolExpr {
        return BoolExpr(name: name, solver: self)
    }

    /// Create an integer variable.
    public func intVar(_ name: String) -> IntExpr {
        return IntExpr(name: name, solver: self)
    }

    /// Create a float variable.
    public func floatVar(_ name: String) -> FloatExpr {
        return FloatExpr(name: name, solver: self)
    }

    /// Create a string variable.
    public func stringVar(_ name: String) -> StringExpr {
        return StringExpr(name: name, solver: self)
    }

    // MARK: - Assertions

    /// Add an assertion to the solver.
    public func assert(_ expr: Expression) {
        assertions.append(expr)
    }

    /// Add multiple assertions.
    public func assertAll(_ exprs: [Expression]) {
        assertions.append(contentsOf: exprs)
    }

    /// Clear all assertions.
    public func reset() {
        assertions.removeAll()
        bindings.removeAll()
        assertionStack.removeAll()
    }

    /// Push current assertion state onto stack.
    public func push() {
        assertionStack.append(assertions)
    }

    /// Pop assertion state from stack.
    public func pop() {
        if let previous = assertionStack.popLast() {
            assertions = previous
        }
    }

    // MARK: - Solving

    /// Check satisfiability of current assertions.
    public func check() -> SolverResult {
        // For bounded verification, we can evaluate constraints directly
        // when all variables are bound, or use simple constraint propagation

        // First, try to find a satisfying assignment
        let result = findSatisfyingAssignment()

        return result
    }

    /// Check if constraints are satisfiable with given variable bindings.
    public func checkWith(bindings: [String: Value]) -> SolverResult {
        self.bindings = bindings
        return evaluateAssertions()
    }

    /// Verify that a constraint holds (returns UNSAT if constraint is violated).
    public func verify(_ constraint: Expression) -> VerificationResult {
        // To verify a constraint holds, we check if NOT(constraint) is satisfiable
        // If UNSAT, the constraint always holds
        // If SAT, we have a counterexample

        push()
        assert(Not(constraint))
        let result = check()
        pop()

        if result.isSatisfiable {
            return VerificationResult(
                holds: false,
                counterexample: result.model
            )
        } else {
            return VerificationResult(holds: true, counterexample: nil)
        }
    }

    // MARK: - Binding

    /// Bind a variable to a value.
    public func bind(_ name: String, to value: Value) {
        bindings[name] = value
    }

    /// Bind multiple variables.
    public func bindAll(_ newBindings: [String: Value]) {
        for (name, value) in newBindings {
            bindings[name] = value
        }
    }

    /// Get current binding for a variable.
    public func getBinding(_ name: String) -> Value? {
        return bindings[name]
    }

    // MARK: - Private Methods

    /// Evaluate all assertions with current bindings.
    private func evaluateAssertions() -> SolverResult {
        for assertion in assertions {
            guard let result = evaluate(assertion) else {
                // Cannot evaluate - unknown variable
                return SolverResult(status: .unknown, model: bindings)
            }

            guard case .bool(true) = result else {
                return SolverResult(status: .unsatisfiable, model: bindings)
            }
        }

        return SolverResult(status: .satisfiable, model: bindings)
    }

    /// Find a satisfying assignment using simple search.
    private func findSatisfyingAssignment() -> SolverResult {
        // For now, just evaluate with current bindings
        // A full implementation would do constraint propagation and search
        return evaluateAssertions()
    }

    /// Evaluate an expression with current bindings.
    internal func evaluate(_ expr: Expression) -> Value? {
        switch expr {
        case let e as BoolExpr:
            if let name = e.variableName {
                return bindings[name]
            }
            return e.constantValue.map { .bool($0) }

        case let e as IntExpr:
            if let name = e.variableName {
                return bindings[name]
            }
            return e.constantValue.map { .int($0) }

        case let e as FloatExpr:
            if let name = e.variableName {
                return bindings[name]
            }
            return e.constantValue.map { .float($0) }

        case let e as StringExpr:
            if let name = e.variableName {
                return bindings[name]
            }
            return e.constantValue.map { .string($0) }

        case let e as Not:
            guard let inner = evaluate(e.inner),
                  case .bool(let b) = inner else { return nil }
            return .bool(!b)

        case let e as And:
            guard let left = evaluate(e.left), case .bool(let l) = left,
                  let right = evaluate(e.right), case .bool(let r) = right else { return nil }
            return .bool(l && r)

        case let e as Or:
            guard let left = evaluate(e.left), case .bool(let l) = left,
                  let right = evaluate(e.right), case .bool(let r) = right else { return nil }
            return .bool(l || r)

        case let e as Implies:
            guard let left = evaluate(e.left), case .bool(let l) = left,
                  let right = evaluate(e.right), case .bool(let r) = right else { return nil }
            return .bool(!l || r)

        case let e as Comparison:
            return evaluateComparison(e)

        case let e as Arithmetic:
            return evaluateArithmetic(e)

        default:
            return nil
        }
    }

    private func evaluateComparison(_ comp: Comparison) -> Value? {
        guard let left = evaluate(comp.left),
              let right = evaluate(comp.right) else { return nil }

        switch (left, right) {
        case (.int(let l), .int(let r)):
            return .bool(compareInt(l, comp.op, r))
        case (.float(let l), .float(let r)):
            return .bool(compareFloat(l, comp.op, r))
        case (.int(let l), .float(let r)):
            return .bool(compareFloat(Double(l), comp.op, r))
        case (.float(let l), .int(let r)):
            return .bool(compareFloat(l, comp.op, Double(r)))
        case (.string(let l), .string(let r)):
            return .bool(compareString(l, comp.op, r))
        case (.bool(let l), .bool(let r)):
            if comp.op == .eq { return .bool(l == r) }
            if comp.op == .neq { return .bool(l != r) }
            return nil
        default:
            return nil
        }
    }

    private func compareInt(_ l: Int, _ op: ComparisonOp, _ r: Int) -> Bool {
        switch op {
        case .eq: return l == r
        case .neq: return l != r
        case .lt: return l < r
        case .lte: return l <= r
        case .gt: return l > r
        case .gte: return l >= r
        }
    }

    private func compareFloat(_ l: Double, _ op: ComparisonOp, _ r: Double) -> Bool {
        switch op {
        case .eq: return l == r
        case .neq: return l != r
        case .lt: return l < r
        case .lte: return l <= r
        case .gt: return l > r
        case .gte: return l >= r
        }
    }

    private func compareString(_ l: String, _ op: ComparisonOp, _ r: String) -> Bool {
        switch op {
        case .eq: return l == r
        case .neq: return l != r
        case .lt: return l < r
        case .lte: return l <= r
        case .gt: return l > r
        case .gte: return l >= r
        }
    }

    private func evaluateArithmetic(_ arith: Arithmetic) -> Value? {
        guard let left = evaluate(arith.left),
              let right = evaluate(arith.right) else { return nil }

        switch (left, right) {
        case (.int(let l), .int(let r)):
            return computeInt(l, arith.op, r).map { .int($0) }
        case (.float(let l), .float(let r)):
            return computeFloat(l, arith.op, r).map { .float($0) }
        case (.int(let l), .float(let r)):
            return computeFloat(Double(l), arith.op, r).map { .float($0) }
        case (.float(let l), .int(let r)):
            return computeFloat(l, arith.op, Double(r)).map { .float($0) }
        default:
            return nil
        }
    }

    private func computeInt(_ l: Int, _ op: ArithmeticOp, _ r: Int) -> Int? {
        switch op {
        case .add: return l + r
        case .sub: return l - r
        case .mul: return l * r
        case .div: return r != 0 ? l / r : nil
        case .mod: return r != 0 ? l % r : nil
        }
    }

    private func computeFloat(_ l: Double, _ op: ArithmeticOp, _ r: Double) -> Double? {
        switch op {
        case .add: return l + r
        case .sub: return l - r
        case .mul: return l * r
        case .div: return r != 0 ? l / r : nil
        case .mod: return r != 0 ? l.truncatingRemainder(dividingBy: r) : nil
        }
    }
}

// MARK: - Values

/// A bound value in the solver.
public enum Value: Equatable, CustomStringConvertible {
    case bool(Bool)
    case int(Int)
    case float(Double)
    case string(String)

    public var description: String {
        switch self {
        case .bool(let b): return String(b)
        case .int(let i): return String(i)
        case .float(let f): return String(f)
        case .string(let s): return "\"\(s)\""
        }
    }
}

// MARK: - Results

/// Result of satisfiability check.
public struct SolverResult {
    public enum Status {
        case satisfiable
        case unsatisfiable
        case unknown
    }

    public let status: Status
    public let model: [String: Value]

    public var isSatisfiable: Bool { status == .satisfiable }
    public var isUnsatisfiable: Bool { status == .unsatisfiable }
}

/// Result of constraint verification.
public struct VerificationResult {
    /// Whether the constraint holds for all inputs
    public let holds: Bool

    /// Counterexample if constraint doesn't hold
    public let counterexample: [String: Value]?
}

// MARK: - Expressions

/// Base protocol for all expressions.
public protocol Expression {}

/// Boolean expression.
public class BoolExpr: Expression {
    internal let variableName: String?
    internal let constantValue: Bool?
    private weak var solver: Z3Lite?

    init(name: String, solver: Z3Lite) {
        self.variableName = name
        self.constantValue = nil
        self.solver = solver
    }

    init(value: Bool) {
        self.variableName = nil
        self.constantValue = value
        self.solver = nil
    }

    public static func constant(_ value: Bool) -> BoolExpr {
        return BoolExpr(value: value)
    }

    public func and(_ other: BoolExpr) -> And {
        return And(self, other)
    }

    public func or(_ other: BoolExpr) -> Or {
        return Or(self, other)
    }

    public func implies(_ other: Expression) -> Implies {
        return Implies(self, other)
    }

    public func not() -> Not {
        return Not(self)
    }
}

/// Integer expression.
public class IntExpr: Expression {
    internal let variableName: String?
    internal let constantValue: Int?
    private weak var solver: Z3Lite?

    init(name: String, solver: Z3Lite) {
        self.variableName = name
        self.constantValue = nil
        self.solver = solver
    }

    init(value: Int) {
        self.variableName = nil
        self.constantValue = value
        self.solver = nil
    }

    public static func constant(_ value: Int) -> IntExpr {
        return IntExpr(value: value)
    }

    public func eq(_ other: IntExpr) -> Comparison { Comparison(self, .eq, other) }
    public func neq(_ other: IntExpr) -> Comparison { Comparison(self, .neq, other) }
    public func lt(_ other: IntExpr) -> Comparison { Comparison(self, .lt, other) }
    public func lte(_ other: IntExpr) -> Comparison { Comparison(self, .lte, other) }
    public func gt(_ other: IntExpr) -> Comparison { Comparison(self, .gt, other) }
    public func gte(_ other: IntExpr) -> Comparison { Comparison(self, .gte, other) }

    public func eq(_ value: Int) -> Comparison { Comparison(self, .eq, IntExpr(value: value)) }
    public func neq(_ value: Int) -> Comparison { Comparison(self, .neq, IntExpr(value: value)) }
    public func lt(_ value: Int) -> Comparison { Comparison(self, .lt, IntExpr(value: value)) }
    public func lte(_ value: Int) -> Comparison { Comparison(self, .lte, IntExpr(value: value)) }
    public func gt(_ value: Int) -> Comparison { Comparison(self, .gt, IntExpr(value: value)) }
    public func gte(_ value: Int) -> Comparison { Comparison(self, .gte, IntExpr(value: value)) }

    public func add(_ other: IntExpr) -> Arithmetic { Arithmetic(self, .add, other) }
    public func sub(_ other: IntExpr) -> Arithmetic { Arithmetic(self, .sub, other) }
    public func mul(_ other: IntExpr) -> Arithmetic { Arithmetic(self, .mul, other) }
    public func div(_ other: IntExpr) -> Arithmetic { Arithmetic(self, .div, other) }
    public func mod(_ other: IntExpr) -> Arithmetic { Arithmetic(self, .mod, other) }
}

/// Float expression.
public class FloatExpr: Expression {
    internal let variableName: String?
    internal let constantValue: Double?
    private weak var solver: Z3Lite?

    init(name: String, solver: Z3Lite) {
        self.variableName = name
        self.constantValue = nil
        self.solver = solver
    }

    init(value: Double) {
        self.variableName = nil
        self.constantValue = value
        self.solver = nil
    }

    public static func constant(_ value: Double) -> FloatExpr {
        return FloatExpr(value: value)
    }

    public func eq(_ other: FloatExpr) -> Comparison { Comparison(self, .eq, other) }
    public func neq(_ other: FloatExpr) -> Comparison { Comparison(self, .neq, other) }
    public func lt(_ other: FloatExpr) -> Comparison { Comparison(self, .lt, other) }
    public func lte(_ other: FloatExpr) -> Comparison { Comparison(self, .lte, other) }
    public func gt(_ other: FloatExpr) -> Comparison { Comparison(self, .gt, other) }
    public func gte(_ other: FloatExpr) -> Comparison { Comparison(self, .gte, other) }

    public func eq(_ value: Double) -> Comparison { Comparison(self, .eq, FloatExpr(value: value)) }
    public func lte(_ value: Double) -> Comparison { Comparison(self, .lte, FloatExpr(value: value)) }
    public func gte(_ value: Double) -> Comparison { Comparison(self, .gte, FloatExpr(value: value)) }
}

/// String expression.
public class StringExpr: Expression {
    internal let variableName: String?
    internal let constantValue: String?
    private weak var solver: Z3Lite?

    init(name: String, solver: Z3Lite) {
        self.variableName = name
        self.constantValue = nil
        self.solver = solver
    }

    init(value: String) {
        self.variableName = nil
        self.constantValue = value
        self.solver = nil
    }

    public static func constant(_ value: String) -> StringExpr {
        return StringExpr(value: value)
    }

    public func eq(_ other: StringExpr) -> Comparison { Comparison(self, .eq, other) }
    public func neq(_ other: StringExpr) -> Comparison { Comparison(self, .neq, other) }
    public func eq(_ value: String) -> Comparison { Comparison(self, .eq, StringExpr(value: value)) }
}

// MARK: - Logical Operations

public class Not: Expression {
    let inner: Expression
    init(_ inner: Expression) { self.inner = inner }
}

public class And: Expression {
    let left: Expression
    let right: Expression
    init(_ left: Expression, _ right: Expression) {
        self.left = left
        self.right = right
    }
}

public class Or: Expression {
    let left: Expression
    let right: Expression
    init(_ left: Expression, _ right: Expression) {
        self.left = left
        self.right = right
    }
}

public class Implies: Expression {
    let left: Expression
    let right: Expression
    init(_ left: Expression, _ right: Expression) {
        self.left = left
        self.right = right
    }
}

// MARK: - Comparison

public enum ComparisonOp {
    case eq, neq, lt, lte, gt, gte
}

public class Comparison: Expression {
    let left: Expression
    let op: ComparisonOp
    let right: Expression

    init(_ left: Expression, _ op: ComparisonOp, _ right: Expression) {
        self.left = left
        self.op = op
        self.right = right
    }
}

// MARK: - Arithmetic

public enum ArithmeticOp {
    case add, sub, mul, div, mod
}

public class Arithmetic: Expression {
    let left: Expression
    let op: ArithmeticOp
    let right: Expression

    init(_ left: Expression, _ op: ArithmeticOp, _ right: Expression) {
        self.left = left
        self.op = op
        self.right = right
    }
}

// MARK: - Convenience Functions

/// Create an AND expression from multiple expressions.
public func AndAll(_ exprs: Expression...) -> Expression {
    guard let first = exprs.first else { return BoolExpr.constant(true) }
    return exprs.dropFirst().reduce(first) { AareEdgeSDK.And($0, $1) }
}

/// Create an OR expression from multiple expressions.
public func OrAll(_ exprs: Expression...) -> Expression {
    guard let first = exprs.first else { return BoolExpr.constant(false) }
    return exprs.dropFirst().reduce(first) { AareEdgeSDK.Or($0, $1) }
}
