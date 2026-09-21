import Foundation

indirect enum MathExpression: Sendable {
  case number(Double)
  case variable
  case negated(MathExpression)
  case function(MathFunction, MathExpression)
  case binary(MathBinaryOperator, MathExpression, MathExpression)

  func evaluate(x: Double) -> Double {
    switch self {
    case .number(let value):
      value
    case .variable:
      x
    case .negated(let expression):
      -expression.evaluate(x: x)
    case .function(let function, let expression):
      function.evaluate(expression.evaluate(x: x))
    case .binary(let operation, let left, let right):
      operation.evaluate(left.evaluate(x: x), right.evaluate(x: x))
    }
  }
}

enum MathFunction: String, Sendable {
  case sin
  case cos
  case tan
  case asin
  case acos
  case atan
  case abs
  case sqrt
  case log
  case naturalLog = "ln"
  case exp
  case floor
  case ceil

  func evaluate(_ value: Double) -> Double {
    if let result = trigonometricValue(value) {
      return result
    }
    return otherValue(value)
  }

  private func trigonometricValue(_ value: Double) -> Double? {
    switch self {
    case .sin: Foundation.sin(value)
    case .cos: Foundation.cos(value)
    case .tan: Foundation.tan(value)
    case .asin: Foundation.asin(value)
    case .acos: Foundation.acos(value)
    case .atan: Foundation.atan(value)
    default: nil
    }
  }

  private func otherValue(_ value: Double) -> Double {
    switch self {
    case .abs: Swift.abs(value)
    case .sqrt: Foundation.sqrt(value)
    case .log, .naturalLog: Foundation.log(value)
    case .exp: Foundation.exp(value)
    case .floor: Foundation.floor(value)
    case .ceil: Foundation.ceil(value)
    case .sin, .cos, .tan, .asin, .acos, .atan:
      value
    }
  }
}

enum MathBinaryOperator: Sendable {
  case add
  case subtract
  case multiply
  case divide
  case power

  func evaluate(_ left: Double, _ right: Double) -> Double {
    switch self {
    case .add: left + right
    case .subtract: left - right
    case .multiply: left * right
    case .divide: left / right
    case .power: Foundation.pow(left, right)
    }
  }
}

enum MathExpressionError: Error, LocalizedError {
  case empty
  case invalidCharacter(Character, Int)
  case invalidNumber(String)
  case unexpectedToken(String)
  case missingClosingParenthesis
  case unknownIdentifier(String)
  case trailingInput

  var errorDescription: String? {
    switch self {
    case .empty:
      "Enter a formula using x."
    case .invalidCharacter(let character, let position):
      "Unsupported character ‘\(character)’ at position \(position + 1)."
    case .invalidNumber(let value):
      "‘\(value)’ is not a valid number."
    case .unexpectedToken(let token):
      "The formula cannot use ‘\(token)’ here."
    case .missingClosingParenthesis:
      "A closing parenthesis is missing."
    case .unknownIdentifier(let identifier):
      "Unknown name ‘\(identifier)’."
    case .trailingInput:
      "The formula has extra input at the end."
    }
  }
}

struct MathExpressionParser {
  private let tokens: [MathToken]
  private var index = 0

  init(_ source: String) throws {
    tokens = try MathLexer.tokenize(source)
  }

  mutating func parse() throws -> MathExpression {
    guard !tokens.isEmpty else { throw MathExpressionError.empty }
    let expression = try parseAdditive()
    guard isAtEnd else { throw MathExpressionError.trailingInput }
    return expression
  }

  private mutating func parseAdditive() throws -> MathExpression {
    var expression = try parseMultiplicative()
    while let token = current {
      switch token {
      case .plus:
        advance()
        expression = .binary(.add, expression, try parseMultiplicative())
      case .minus:
        advance()
        expression = .binary(.subtract, expression, try parseMultiplicative())
      default:
        return expression
      }
    }
    return expression
  }

  private mutating func parseMultiplicative() throws -> MathExpression {
    var expression = try parseUnary()
    while let token = current {
      switch token {
      case .multiply:
        advance()
        expression = .binary(.multiply, expression, try parseUnary())
      case .divide:
        advance()
        expression = .binary(.divide, expression, try parseUnary())
      default:
        return expression
      }
    }
    return expression
  }

  private mutating func parseUnary() throws -> MathExpression {
    guard let token = current else {
      throw MathExpressionError.unexpectedToken("end of formula")
    }
    switch token {
    case .plus:
      advance()
      return try parseUnary()
    case .minus:
      advance()
      return .negated(try parseUnary())
    default:
      return try parsePower()
    }
  }

  private mutating func parsePower() throws -> MathExpression {
    let left = try parsePrimary()
    guard current == .power else { return left }
    advance()
    return .binary(.power, left, try parseUnary())
  }

  private mutating func parsePrimary() throws -> MathExpression {
    guard let token = current else {
      throw MathExpressionError.unexpectedToken("end of formula")
    }
    advance()
    switch token {
    case .number(let value):
      return .number(value)
    case .identifier(let identifier):
      return try parseIdentifier(identifier)
    case .leftParenthesis:
      let expression = try parseAdditive()
      guard current == .rightParenthesis else {
        throw MathExpressionError.missingClosingParenthesis
      }
      advance()
      return expression
    default:
      throw MathExpressionError.unexpectedToken(token.description)
    }
  }

  private mutating func parseIdentifier(_ identifier: String) throws -> MathExpression {
    switch identifier {
    case "x":
      return .variable
    case "pi":
      return .number(.pi)
    case "e":
      return .number(M_E)
    default:
      guard let function = MathFunction(rawValue: identifier) else {
        throw MathExpressionError.unknownIdentifier(identifier)
      }
      guard current == .leftParenthesis else {
        throw MathExpressionError.unexpectedToken(identifier)
      }
      advance()
      let argument = try parseAdditive()
      guard current == .rightParenthesis else {
        throw MathExpressionError.missingClosingParenthesis
      }
      advance()
      return .function(function, argument)
    }
  }

  private var current: MathToken? {
    index < tokens.count ? tokens[index] : nil
  }

  private var isAtEnd: Bool {
    index == tokens.count
  }

  private mutating func advance() {
    index += 1
  }
}

private enum MathToken: Equatable, CustomStringConvertible {
  case number(Double)
  case identifier(String)
  case plus
  case minus
  case multiply
  case divide
  case power
  case leftParenthesis
  case rightParenthesis

  var description: String {
    switch self {
    case .number(let value): value.formatted()
    case .identifier(let value): value
    case .plus: "+"
    case .minus: "−"
    case .multiply: "×"
    case .divide: "÷"
    case .power: "^"
    case .leftParenthesis: "("
    case .rightParenthesis: ")"
    }
  }
}

private enum MathLexer {
  static func tokenize(_ source: String) throws -> [MathToken] {
    let characters = Array(source.lowercased())
    var tokens: [MathToken] = []
    var index = 0
    while index < characters.count {
      let character = characters[index]
      if character.isWhitespace {
        index += 1
      } else if character.isNumber || character == "." {
        let result = try readNumber(in: characters, from: index)
        tokens.append(.number(result.value))
        index = result.nextIndex
      } else if character.isLetter {
        let result = readIdentifier(in: characters, from: index)
        tokens.append(.identifier(result.value))
        index = result.nextIndex
      } else {
        tokens.append(try token(for: character, at: index))
        index += 1
      }
    }
    return tokens
  }

  private static func readNumber(
    in characters: [Character],
    from start: Int
  ) throws -> (value: Double, nextIndex: Int) {
    var index = start
    var hasExponent = false
    while index < characters.count {
      let character = characters[index]
      if character.isNumber || character == "." {
        index += 1
      } else if (character == "e" || character == "E") && !hasExponent {
        hasExponent = true
        index += 1
        if index < characters.count, characters[index] == "+" || characters[index] == "-" {
          index += 1
        }
      } else {
        break
      }
    }
    let text = String(characters[start..<index])
    guard let value = Double(text) else {
      throw MathExpressionError.invalidNumber(text)
    }
    return (value, index)
  }

  private static func readIdentifier(
    in characters: [Character],
    from start: Int
  ) -> (value: String, nextIndex: Int) {
    var index = start
    while index < characters.count, characters[index].isLetter {
      index += 1
    }
    return (String(characters[start..<index]), index)
  }

  private static func token(for character: Character, at index: Int) throws -> MathToken {
    switch character {
    case "+": .plus
    case "-", "−": .minus
    case "*", "×": .multiply
    case "/", "÷": .divide
    case "^": .power
    case "(": .leftParenthesis
    case ")": .rightParenthesis
    default: throw MathExpressionError.invalidCharacter(character, index)
    }
  }
}
