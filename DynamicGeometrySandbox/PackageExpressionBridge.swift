import DynamicGeometry

extension MathExpression {
  func scalarExpression(variableID: ScalarParameterID) throws -> ScalarExpression {
    switch self {
    case .number(let value):
      .constant(value)
    case .variable:
      .parameter(.identified(variableID))
    case .negated(let expression):
      .negation(try expression.scalarExpression(variableID: variableID))
    case .function(let function, let expression):
      .function(
        try function.scalarFunction,
        argument: try expression.scalarExpression(variableID: variableID))
    case .binary(let operation, let left, let right):
      .arithmetic(
        left: try left.scalarExpression(variableID: variableID),
        operation: operation.scalarOperator,
        right: try right.scalarExpression(variableID: variableID))
    }
  }
}

private extension MathFunction {
  var scalarFunction: ScalarFunction {
    get throws {
      switch self {
      case .sin: .sine
      case .cos: .cosine
      case .tan: .tangent
      case .abs: .absoluteValue
      case .sqrt: .squareRoot
      case .log, .naturalLog: .naturalLogarithm
      case .exp: .exponential
      case .asin, .acos, .atan, .floor, .ceil:
        throw MathExpressionError.unsupportedPackageFunction(rawValue)
      }
    }
  }
}

private extension MathBinaryOperator {
  var scalarOperator: ScalarArithmeticOperator {
    switch self {
    case .add: .addition
    case .subtract: .subtraction
    case .multiply: .multiplication
    case .divide: .division
    case .power: .power
    }
  }
}
