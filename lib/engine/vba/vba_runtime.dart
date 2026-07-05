import 'dart:math';

class VbaRuntime {
  final Map<String, dynamic> _globals = {};
  final Map<String, VbaFunction> _functions = {};
  final List<VbaModule> _modules = [];
  final VbaErrorHandler _errorHandler = VbaErrorHandler();

  VbaRuntime() {
    _globals['ActivePresentation'] = {'Slides': <Map<String, dynamic>>[]};
    _registerBuiltInFunctions();
  }

  void _registerBuiltInFunctions() {
    _functions['MsgBox'] = VbaFunction((args) {
      final message = args.isNotEmpty ? args[0].toString() : '';
      _globals['LastMsgBox'] = message;
      return 0;
    });

    _functions['InputBox'] = VbaFunction((args) {
      final prompt = args.isNotEmpty ? args[0].toString() : '';
      _globals['LastInputBoxPrompt'] = prompt;
      return args.length > 1 ? args[1].toString() : '';
    });

    _functions['RGB'] = VbaFunction((args) {
      if (args.length < 3) return 0;
      final r = (args[0] as num).toInt();
      final g = (args[1] as num).toInt();
      final b = (args[2] as num).toInt();
      return (r << 16) | (g << 8) | b;
    });

    _functions['Rnd'] = VbaFunction((args) {
      return Random().nextDouble();
    });

    _functions['Now'] = VbaFunction((args) {
      return DateTime.now();
    });

    _functions['Len'] = VbaFunction((args) {
      if (args.isEmpty) return 0;
      return args[0].toString().length;
    });

    _functions['Mid'] = VbaFunction((args) {
      if (args.length < 3) return '';
      final str = args[0].toString();
      final start = (args[1] as num).toInt() - 1; // VBA is 1-based
      final length = (args[2] as num).toInt();
      if (start < 0 || start >= str.length) return '';
      return str.substring(start, (start + length).clamp(0, str.length));
    });

    _functions['UCase'] = VbaFunction((args) {
      if (args.isEmpty) return '';
      return args[0].toString().toUpperCase();
    });

    _functions['LCase'] = VbaFunction((args) {
      if (args.isEmpty) return '';
      return args[0].toString().toLowerCase();
    });

    _functions['Trim'] = VbaFunction((args) {
      if (args.isEmpty) return '';
      return args[0].toString().trim();
    });

    _functions['Int'] = VbaFunction((args) {
      if (args.isEmpty) return 0;
      return (args[0] as num).toInt();
    });

    _functions['Abs'] = VbaFunction((args) {
      if (args.isEmpty) return 0;
      return (args[0] as num).abs();
    });

    _functions['Sqr'] = VbaFunction((args) {
      if (args.isEmpty) return 0;
      return sqrt(args[0] as num);
    });

    // PowerPoint-specific
    _functions['ActivePresentation'] = VbaFunction((args) {
      return _globals['ActivePresentation'];
    });

    _functions['Slides'] = VbaFunction((args) {
      final pres = _globals['ActivePresentation'];
      return pres?['Slides'] ?? [];
    });

    _functions['Shapes'] = VbaFunction((args) {
      if (args.isEmpty) return [];
      final slide = args[0];
      return slide?['Shapes'] ?? [];
    });

    _functions['AddSlide'] = VbaFunction((args) {
      final presentation = _activePresentation();
      final slides = presentation['Slides'] as List<Map<String, dynamic>>;
      final requestedIndex = args.isNotEmpty && args[0] is num
          ? (args[0] as num).toInt()
          : slides.length + 1;
      final insertIndex = requestedIndex.clamp(1, slides.length + 1).toInt();
      final slide = {
        'Index': insertIndex,
        'Layout': args.length > 1 ? args[1] : null,
        'Shapes': <Map<String, dynamic>>[],
      };
      slides.insert(insertIndex - 1, slide);
      _renumberSlides(slides);
      return slide;
    });

    _functions['AddShape'] = VbaFunction((args) {
      final hasSlideArg =
          args.isNotEmpty &&
          args.first is Map &&
          (args.first as Map).containsKey('Shapes');
      if (args.length < (hasSlideArg ? 6 : 5)) return null;
      final slide = hasSlideArg
          ? args.first as Map<String, dynamic>
          : _currentSlide();
      final offset = hasSlideArg ? 1 : 0;
      final shape = {
        'Type': args[offset],
        'Left': args[offset + 1],
        'Top': args[offset + 2],
        'Width': args[offset + 3],
        'Height': args[offset + 4],
        'TextFrame': {
          'TextRange': {'Text': ''},
        },
      };
      final shapes = slide['Shapes'] as List<Map<String, dynamic>>;
      shape['Id'] = shapes.length + 1;
      shapes.add(shape);
      return shape;
    });

    _functions['TextFrame'] = VbaFunction((args) {
      if (args.isEmpty) return null;
      final shape = args[0];
      if (shape is Map<String, dynamic>) {
        return shape.putIfAbsent('TextFrame', () {
          return {
            'TextRange': {'Text': ''},
          };
        });
      }
      return {
        'TextRange': {'Text': ''},
      };
    });

    _functions['TextRange'] = VbaFunction((args) {
      if (args.isEmpty) return null;
      final textFrame = args[0];
      if (textFrame is Map<String, dynamic>) {
        return textFrame.putIfAbsent('TextRange', () {
          return {'Text': '', 'Paragraphs': []};
        });
      }
      return {'Text': '', 'Paragraphs': []};
    });
  }

  Map<String, dynamic> _activePresentation() {
    final presentation = _globals['ActivePresentation'];
    if (presentation is Map<String, dynamic>) return presentation;
    final created = {'Slides': <Map<String, dynamic>>[]};
    _globals['ActivePresentation'] = created;
    return created;
  }

  Map<String, dynamic> _currentSlide() {
    final presentation = _activePresentation();
    final slides = presentation['Slides'] as List<Map<String, dynamic>>;
    if (slides.isEmpty) {
      return _functions['AddSlide']!.call(const []) as Map<String, dynamic>;
    }
    return slides.last;
  }

  void _renumberSlides(List<Map<String, dynamic>> slides) {
    for (int i = 0; i < slides.length; i++) {
      slides[i]['Index'] = i + 1;
    }
  }

  dynamic getGlobal(String name) => _globals[name];

  void setGlobal(String name, dynamic value) {
    _globals[name] = value;
  }

  dynamic execute(String code) {
    final parser = VbaParser(code);
    final ast = parser.parse();
    return _executeBlock(ast);
  }

  dynamic executeModule(String name) {
    final module = _modules.firstWhere(
      (m) => m.name == name,
      orElse: () => throw ArgumentError.value(name, 'name', 'Module not found'),
    );
    return execute(module.source);
  }

  void addModule(String name, String source) {
    final existingIndex = _modules.indexWhere((m) => m.name == name);
    final module = VbaModule(name: name, source: source);
    if (existingIndex >= 0) {
      _modules[existingIndex] = module;
    } else {
      _modules.add(module);
    }
  }

  List<String> get moduleNames => _modules.map((m) => m.name).toList();

  dynamic _executeBlock(List<VbaStatement> statements) {
    dynamic lastResult;
    final labels = <String, int>{};
    for (int i = 0; i < statements.length; i++) {
      final stmt = statements[i];
      if (stmt is VbaLabelStatement) {
        labels[stmt.label.toLowerCase()] = i;
      }
    }

    var index = 0;
    var jumps = 0;
    while (index < statements.length) {
      final stmt = statements[index];
      lastResult = _executeStatement(stmt);
      if (stmt is VbaExitStatement) break;
      if (stmt is VbaGoToStatement) {
        final targetIndex = labels[stmt.label.toLowerCase()];
        if (targetIndex == null) {
          throw VbaRuntimeError(1001, 'Label not found: ${stmt.label}');
        }
        jumps++;
        if (jumps > 10000) {
          throw VbaRuntimeError(1002, 'GoTo jump limit exceeded');
        }
        index = targetIndex + 1;
        continue;
      }
      index++;
    }
    return lastResult;
  }

  dynamic _executeStatement(VbaStatement stmt) {
    if (stmt is VbaAssignment) {
      final value = _evaluateExpression(stmt.value);
      _globals[stmt.variable] = value;
      return value;
    } else if (stmt is VbaFunctionCall) {
      return _callFunction(stmt.name, stmt.arguments);
    } else if (stmt is VbaIfStatement) {
      final condition = _evaluateExpression(stmt.condition);
      if (_toBool(condition)) {
        return _executeBlock(stmt.thenBlock);
      } else if (stmt.elseBlock != null) {
        return _executeBlock(stmt.elseBlock!);
      }
    } else if (stmt is VbaForLoop) {
      final start = _evaluateExpression(stmt.start);
      final end = _evaluateExpression(stmt.end);
      final step = stmt.step != null ? _evaluateExpression(stmt.step!) : 1;

      for (
        var i = (start as num).toInt();
        i <= (end as num).toInt();
        i += (step as num).toInt()
      ) {
        _globals[stmt.variable] = i;
        _executeBlock(stmt.body);
      }
    } else if (stmt is VbaWhileLoop) {
      while (_toBool(_evaluateExpression(stmt.condition))) {
        _executeBlock(stmt.body);
      }
    } else if (stmt is VbaDoUntilLoop) {
      do {
        _executeBlock(stmt.body);
      } while (!_toBool(_evaluateExpression(stmt.condition)));
    } else if (stmt is VbaSelectCase) {
      final value = _evaluateExpression(stmt.expression);
      for (final case_ in stmt.cases) {
        if (case_.values.any((v) => _evaluateExpression(v) == value)) {
          return _executeBlock(case_.body);
        }
      }
      if (stmt.defaultCase != null) {
        return _executeBlock(stmt.defaultCase!);
      }
    } else if (stmt is VbaWithStatement) {
      final obj = _evaluateExpression(stmt.object);
      _globals['__with_object'] = obj;
      _executeBlock(stmt.body);
      _globals.remove('__with_object');
    } else if (stmt is VbaDimStatement) {
      if (stmt.initialValue != null) {
        _globals[stmt.variable] = _evaluateExpression(stmt.initialValue!);
      } else {
        _globals[stmt.variable] = _getDefaultValue(stmt.type);
      }
    } else if (stmt is VbaSubDefinition) {
      _functions[stmt.name] = VbaFunction((args) {
        // Map arguments to parameters
        for (int i = 0; i < stmt.parameters.length && i < args.length; i++) {
          _globals[stmt.parameters[i]] = args[i];
        }
        return _executeBlock(stmt.body);
      });
    } else if (stmt is VbaFunctionDefinition) {
      _functions[stmt.name] = VbaFunction((args) {
        for (int i = 0; i < stmt.parameters.length && i < args.length; i++) {
          _globals[stmt.parameters[i]] = args[i];
        }
        return _executeBlock(stmt.body);
      });
    } else if (stmt is VbaReturnStatement) {
      return _evaluateExpression(stmt.value);
    } else if (stmt is VbaOnErrorStatement) {
      _errorHandler.setHandler(stmt.label);
    } else if (stmt is VbaGoToStatement) {
      return null;
    } else if (stmt is VbaLabelStatement) {
      // Label marker
    } else if (stmt is VbaComment) {
      // Ignore comments
    }
    return null;
  }

  dynamic _evaluateExpression(VbaExpression expr) {
    if (expr is VbaLiteral) {
      return expr.value;
    } else if (expr is VbaVariable) {
      return _globals[expr.name];
    } else if (expr is VbaBinaryExpression) {
      final left = _evaluateExpression(expr.left);
      final right = _evaluateExpression(expr.right);
      return _applyOperator(expr.operator, left, right);
    } else if (expr is VbaUnaryExpression) {
      final value = _evaluateExpression(expr.operand);
      if (expr.operator == '-') return -(value as num);
      if (expr.operator == 'Not') return !_toBool(value);
      return value;
    } else if (expr is VbaFunctionCall) {
      return _callFunction(expr.name, expr.arguments);
    } else if (expr is VbaPropertyAccess) {
      final obj = _evaluateExpression(expr.object);
      if (obj is Map) return obj[expr.property];
      return null;
    } else if (expr is VbaMethodCall) {
      final obj = _evaluateExpression(expr.object);
      if (obj is Map) {
        final method = obj[expr.method];
        if (method is Function) {
          return method(
            expr.arguments.map((a) => _evaluateExpression(a)).toList(),
          );
        }
      }
      return null;
    } else if (expr is VbaArrayAccess) {
      final array = _evaluateExpression(expr.array);
      final index = _evaluateExpression(expr.index);
      if (array is List && index is int) {
        return index >= 0 && index < array.length ? array[index] : null;
      }
      return null;
    } else if (expr is VbaStringConcatenation) {
      final left = _evaluateExpression(expr.left);
      final right = _evaluateExpression(expr.right);
      return left.toString() + right.toString();
    }
    return null;
  }

  dynamic _callFunction(String name, List<VbaExpression> arguments) {
    final func = _functions[name];
    if (func != null) {
      final args = arguments.map((a) => _evaluateExpression(a)).toList();
      return func.call(args);
    }
    return null;
  }

  dynamic _applyOperator(String op, dynamic left, dynamic right) {
    switch (op) {
      case '+':
        return (left as num) + (right as num);
      case '-':
        return (left as num) - (right as num);
      case '*':
        return (left as num) * (right as num);
      case '/':
        return (left as num) / (right as num);
      case '\\':
        return (left as num) ~/ (right as num);
      case '^':
        return pow(left as num, right as num);
      case 'Mod':
        return (left as num) % (right as num);
      case '&':
        return left.toString() + right.toString();
      case '=':
        return left == right;
      case '<>':
        return left != right;
      case '<':
        return (left as num) < (right as num);
      case '>':
        return (left as num) > (right as num);
      case '<=':
        return (left as num) <= (right as num);
      case '>=':
        return (left as num) >= (right as num);
      case 'And':
        return _toBool(left) && _toBool(right);
      case 'Or':
        return _toBool(left) || _toBool(right);
      case 'Xor':
        return _toBool(left) != _toBool(right);
      default:
        return null;
    }
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    return true;
  }

  dynamic _getDefaultValue(String? type) {
    switch (type?.toLowerCase()) {
      case 'integer':
      case 'long':
      case 'byte':
        return 0;
      case 'single':
      case 'double':
      case 'currency':
        return 0.0;
      case 'boolean':
        return false;
      case 'string':
        return '';
      case 'date':
        return DateTime(1899, 12, 30);
      case 'object':
      case 'variant':
        return null;
      default:
        return null;
    }
  }
}

class VbaModule {
  final String name;
  final String source;

  const VbaModule({required this.name, required this.source});
}

class VbaParser {
  final String source;
  int _pos = 0;

  VbaParser(this.source);

  List<VbaStatement> parse() {
    final statements = <VbaStatement>[];
    while (_pos < source.length) {
      _skipWhitespace();
      if (_pos >= source.length) break;

      final stmt = _parseStatement();
      if (stmt != null) statements.add(stmt);
    }
    return statements;
  }

  VbaStatement? _parseStatement() {
    _skipWhitespace();
    if (_match('Sub ')) return _parseSub();
    if (_match('Function ')) return _parseFunction();
    if (_match('Dim ')) return _parseDim();
    if (_match('If ')) return _parseIf();
    if (_match('For ')) return _parseFor();
    if (_match('While ')) return _parseWhile();
    if (_match('Do ')) return _parseDo();
    if (_match('Select Case ')) return _parseSelectCase();
    if (_match('With ')) return _parseWith();
    if (_match('On Error ')) return _parseOnError();
    if (_match('GoTo ')) return _parseGoTo();
    if (_match('Exit ')) return _parseExit();
    if (_match('Return')) return VbaReturnStatement(VbaLiteral(null));
    if (_peek() == "'") return _parseComment();

    // Try assignment or function call
    final expr = _parseExpression();
    if (expr != null) {
      _skipWhitespace();
      if (expr is VbaVariable && _match(':')) {
        return VbaLabelStatement(expr.name);
      } else if (_match('=')) {
        final value = _parseExpression();
        if (value != null && expr is VbaVariable) {
          return VbaAssignment(expr.name, value);
        }
      } else if (expr is VbaFunctionCall) {
        return expr;
      }
    }

    _skipToNextLine();
    return null;
  }

  VbaStatement _parseSub() {
    final name = _parseIdentifier();
    final params = _parseParameterList();
    final body = _parseBlock('End Sub');
    return VbaSubDefinition(name, params, body);
  }

  VbaStatement _parseFunction() {
    final name = _parseIdentifier();
    final params = _parseParameterList();
    final body = _parseBlock('End Function');
    return VbaFunctionDefinition(name, params, body);
  }

  VbaStatement _parseDim() {
    final name = _parseIdentifier();
    String? type;
    VbaExpression? initValue;

    _skipWhitespace();
    if (_match(' As ')) {
      type = _parseIdentifier();
    }

    _skipWhitespace();
    if (_match('=')) {
      initValue = _parseExpression();
    }

    return VbaDimStatement(name, type, initValue);
  }

  VbaStatement _parseIf() {
    final condition = _parseExpression();
    _expect(' Then');
    final thenBlock = _parseBlock(null, elseIfOrElseOrEndIf: true);

    List<VbaElseIf>? elseIfBlocks;
    List<VbaStatement>? elseBlock;

    _skipWhitespace();
    while (_match('ElseIf ')) {
      elseIfBlocks ??= [];
      final elseIfCondition = _parseExpression();
      _expect(' Then');
      final elseIfBody = _parseBlock(null, elseIfOrElseOrEndIf: true);
      elseIfBlocks.add(VbaElseIf(elseIfCondition!, elseIfBody));
    }

    _skipWhitespace();
    if (_match('Else')) {
      elseBlock = _parseBlock('End If');
    } else {
      _expect('End If');
    }

    return VbaIfStatement(condition!, thenBlock, elseIfBlocks, elseBlock);
  }

  VbaStatement _parseFor() {
    final varName = _parseIdentifier();
    _expect('=');
    final start = _parseExpression();
    _expect(' To ');
    final end = _parseExpression();

    VbaExpression? step;
    _skipWhitespace();
    if (_match(' Step ')) {
      step = _parseExpression();
    }

    final body = _parseBlock('Next');
    return VbaForLoop(varName, start!, end!, step, body);
  }

  VbaStatement _parseWhile() {
    final condition = _parseExpression();
    final body = _parseBlock('Wend');
    return VbaWhileLoop(condition!, body);
  }

  VbaStatement _parseDo() {
    final body = _parseBlock(null, untilOrWhile: true);
    _skipWhitespace();
    if (_match('Loop Until ')) {
      final condition = _parseExpression();
      return VbaDoUntilLoop(condition!, body);
    } else if (_match('Loop While ')) {
      final condition = _parseExpression();
      return VbaDoWhileLoop(condition!, body);
    }
    return VbaDoUntilLoop(VbaLiteral(true), body);
  }

  VbaStatement _parseSelectCase() {
    final expr = _parseExpression();
    final cases = <VbaCase>[];
    List<VbaStatement>? defaultCase;

    while (true) {
      _skipWhitespace();
      if (_match('Case Else')) {
        defaultCase = _parseBlock('End Select', caseBlock: true);
        break;
      }
      if (_match('Case ')) {
        final values = <VbaExpression>[];
        do {
          values.add(_parseExpression()!);
          _skipWhitespace();
        } while (_match(','));
        final body = _parseBlock(null, caseBlock: true);
        cases.add(VbaCase(values, body));
      } else if (_match('End Select')) {
        break;
      } else {
        _pos++;
      }
    }

    return VbaSelectCase(expr!, cases, defaultCase);
  }

  VbaStatement _parseWith() {
    final obj = _parseExpression();
    final body = _parseBlock('End With');
    return VbaWithStatement(obj!, body);
  }

  VbaStatement _parseOnError() {
    if (_match('Resume Next')) {
      return VbaOnErrorStatement('ResumeNext');
    } else if (_match('GoTo ')) {
      final label = _parseIdentifier();
      return VbaOnErrorStatement(label);
    }
    return VbaOnErrorStatement('');
  }

  VbaStatement _parseGoTo() {
    final label = _parseIdentifier();
    return VbaGoToStatement(label);
  }

  VbaStatement _parseExit() {
    if (_match(' Sub')) return VbaExitStatement('Sub');
    if (_match(' Function')) return VbaExitStatement('Function');
    if (_match(' For')) return VbaExitStatement('For');
    if (_match(' Do')) return VbaExitStatement('Do');
    return VbaExitStatement('');
  }

  VbaStatement _parseComment() {
    final start = _pos;
    while (_pos < source.length && source[_pos] != '\n') {
      _pos++;
    }
    return VbaComment(source.substring(start, _pos));
  }

  List<VbaStatement> _parseBlock(
    String? endMarker, {
    bool elseIfOrElseOrEndIf = false,
    bool untilOrWhile = false,
    bool caseBlock = false,
  }) {
    final block = <VbaStatement>[];
    while (_pos < source.length) {
      _skipWhitespace();
      if (_pos >= source.length) break;

      if (endMarker != null && _match(endMarker)) break;
      if (elseIfOrElseOrEndIf &&
          (_peekAhead('ElseIf ') || _peekAhead('Else') || _peekAhead('End If')))
        break;
      if (untilOrWhile && (_peekAhead('Loop '))) break;
      if (caseBlock && (_peekAhead('Case ') || _peekAhead('End Select'))) break;

      final stmt = _parseStatement();
      if (stmt != null) block.add(stmt);
    }
    return block;
  }

  VbaExpression? _parseExpression() {
    return _parseOrExpression();
  }

  VbaExpression? _parseOrExpression() {
    final nullable = _parseAndExpression();
    if (nullable == null) return null;
    VbaExpression left = nullable;

    while (true) {
      _skipWhitespace();
      if (_match(' Or ')) {
        final right = _parseAndExpression();
        if (right != null) left = VbaBinaryExpression('Or', left, right);
      } else if (_match(' Xor ')) {
        final right = _parseAndExpression();
        if (right != null) left = VbaBinaryExpression('Xor', left, right);
      } else {
        break;
      }
    }
    return left;
  }

  VbaExpression? _parseAndExpression() {
    final nullable = _parseComparison();
    if (nullable == null) return null;
    VbaExpression left = nullable;

    while (true) {
      _skipWhitespace();
      if (_match(' And ')) {
        final right = _parseComparison();
        if (right != null) left = VbaBinaryExpression('And', left, right);
      } else {
        break;
      }
    }
    return left;
  }

  VbaExpression? _parseComparison() {
    var left = _parseConcatenation();
    if (left == null) return null;

    _skipWhitespace();
    final ops = ['<=', '>=', '<>', '=', '<', '>'];
    for (final op in ops) {
      if (_match(op)) {
        final right = _parseConcatenation();
        if (right != null) {
          return VbaBinaryExpression(op, left, right);
        }
      }
    }
    return left;
  }

  VbaExpression? _parseConcatenation() {
    final nullable = _parseAddition();
    if (nullable == null) return null;
    VbaExpression left = nullable;

    while (true) {
      _skipWhitespace();
      if (_match(' & ')) {
        final right = _parseAddition();
        if (right != null) left = VbaStringConcatenation(left, right);
      } else {
        break;
      }
    }
    return left;
  }

  VbaExpression? _parseAddition() {
    final nullable = _parseMultiplication();
    if (nullable == null) return null;
    VbaExpression left = nullable;

    while (true) {
      _skipWhitespace();
      if (_match('+')) {
        final right = _parseMultiplication();
        if (right != null) left = VbaBinaryExpression('+', left, right);
      } else if (_match('-')) {
        final right = _parseMultiplication();
        if (right != null) left = VbaBinaryExpression('-', left, right);
      } else {
        break;
      }
    }
    return left;
  }

  VbaExpression? _parseMultiplication() {
    final nullable = _parsePower();
    if (nullable == null) return null;
    VbaExpression left = nullable;

    while (true) {
      _skipWhitespace();
      if (_match('*')) {
        final right = _parsePower();
        if (right != null) left = VbaBinaryExpression('*', left, right);
      } else if (_match('/')) {
        final right = _parsePower();
        if (right != null) left = VbaBinaryExpression('/', left, right);
      } else if (_match('\\')) {
        final right = _parsePower();
        if (right != null) left = VbaBinaryExpression('\\', left, right);
      } else if (_match(' Mod ')) {
        final right = _parsePower();
        if (right != null) left = VbaBinaryExpression('Mod', left, right);
      } else {
        break;
      }
    }
    return left;
  }

  VbaExpression? _parsePower() {
    var left = _parseUnary();
    if (left == null) return null;

    _skipWhitespace();
    if (_match('^')) {
      final right = _parseUnary();
      if (right != null) left = VbaBinaryExpression('^', left, right);
    }
    return left;
  }

  VbaExpression? _parseUnary() {
    _skipWhitespace();
    if (_match('-')) {
      final operand = _parseUnary();
      if (operand != null) return VbaUnaryExpression('-', operand);
    }
    if (_match('Not ')) {
      final operand = _parseUnary();
      if (operand != null) return VbaUnaryExpression('Not', operand);
    }
    return _parsePrimary();
  }

  VbaExpression? _parsePrimary() {
    _skipWhitespace();

    // Parenthesized expression
    if (_match('(')) {
      final expr = _parseExpression();
      _expect(')');
      return expr;
    }

    // String literal
    if (_peek() == '"') {
      return _parseStringLiteral();
    }

    // Number literal
    if (_isDigit(_peek()) || (_peek() == '.' && _isDigit(_peekNext()))) {
      return _parseNumberLiteral();
    }

    // Boolean literal
    if (_match('True')) return VbaLiteral(true);
    if (_match('False')) return VbaLiteral(false);
    if (_match('Nothing')) return VbaLiteral(null);
    if (_match('Null')) return VbaLiteral(null);
    if (_match('Empty')) return VbaLiteral(null);

    // Identifier (variable, function call, property access)
    final id = _parseIdentifier();
    if (id.isEmpty) return null;

    return _parsePostfix(VbaVariable(id));
  }

  VbaExpression _parsePostfix(VbaExpression expr) {
    while (true) {
      _skipWhitespace();
      if (_match('(')) {
        // Function call
        final args = <VbaExpression>[];
        if (!_peekAhead(')')) {
          do {
            final arg = _parseExpression();
            if (arg != null) args.add(arg);
            _skipWhitespace();
          } while (_match(','));
        }
        _expect(')');
        if (expr is VbaVariable) {
          expr = VbaFunctionCall(expr.name, args);
        }
      } else if (_match('.')) {
        final prop = _parseIdentifier();
        _skipWhitespace();
        if (_match('(')) {
          // Method call
          final args = <VbaExpression>[];
          if (!_peekAhead(')')) {
            do {
              final arg = _parseExpression();
              if (arg != null) args.add(arg);
              _skipWhitespace();
            } while (_match(','));
          }
          _expect(')');
          expr = VbaMethodCall(expr, prop, args);
        } else {
          // Property access
          expr = VbaPropertyAccess(expr, prop);
        }
      } else if (_match('(')) {
        // Array access
        final index = _parseExpression();
        _expect(')');
        expr = VbaArrayAccess(expr, index!);
      } else {
        break;
      }
    }
    return expr;
  }

  VbaExpression _parseStringLiteral() {
    _pos++; // Skip opening quote
    final buffer = StringBuffer();
    while (_pos < source.length && source[_pos] != '"') {
      if (source[_pos] == '"' && _peekNext() == '"') {
        buffer.write('"');
        _pos += 2;
      } else {
        buffer.write(source[_pos]);
        _pos++;
      }
    }
    _pos++; // Skip closing quote
    return VbaLiteral(buffer.toString());
  }

  VbaExpression _parseNumberLiteral() {
    final start = _pos;
    bool hasDecimal = false;

    while (_pos < source.length &&
        (_isDigit(source[_pos]) || source[_pos] == '.')) {
      if (source[_pos] == '.') {
        if (hasDecimal) break;
        hasDecimal = true;
      }
      _pos++;
    }

    // Check for type suffix
    if (_pos < source.length && '%#&!'.contains(source[_pos])) {
      _pos++;
    }

    final numStr = source.substring(start, _pos);
    if (hasDecimal) {
      return VbaLiteral(double.parse(numStr));
    }
    return VbaLiteral(int.parse(numStr));
  }

  String _parseIdentifier() {
    _skipWhitespace();
    final start = _pos;

    if (_pos < source.length &&
        (_isLetter(source[_pos]) || source[_pos] == '_')) {
      _pos++;
      while (_pos < source.length &&
          (_isLetter(source[_pos]) ||
              _isDigit(source[_pos]) ||
              source[_pos] == '_')) {
        _pos++;
      }
    }

    return source.substring(start, _pos);
  }

  List<String> _parseParameterList() {
    final params = <String>[];
    _skipWhitespace();
    if (_match('(')) {
      if (!_peekAhead(')')) {
        do {
          _skipWhitespace();
          params.add(_parseIdentifier());
          _skipWhitespace();
          // Skip "As Type" if present
          if (_match(' As ')) {
            _parseIdentifier();
          }
        } while (_match(','));
      }
      _expect(')');
    }
    return params;
  }

  void _skipWhitespace() {
    while (_pos < source.length && ' \t\r\n'.contains(source[_pos])) {
      _pos++;
    }
  }

  void _skipToNextLine() {
    while (_pos < source.length && source[_pos] != '\n') {
      _pos++;
    }
    if (_pos < source.length) _pos++;
  }

  bool _match(String pattern) {
    _skipWhitespace();
    if (source.substring(_pos).startsWith(pattern)) {
      _pos += pattern.length;
      return true;
    }
    return false;
  }

  bool _peekAhead(String pattern) {
    _skipWhitespace();
    return source.substring(_pos).startsWith(pattern);
  }

  String _peek() => _pos < source.length ? source[_pos] : '';
  String _peekNext() => _pos + 1 < source.length ? source[_pos + 1] : '';

  bool _isLetter(String ch) =>
      ch.isNotEmpty &&
      (ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90 ||
          ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122);
  bool _isDigit(String ch) =>
      ch.isNotEmpty && ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

  void _expect(String pattern) {
    if (!_match(pattern)) {
      throw Exception('Expected "$pattern" at position $_pos');
    }
  }
}

// AST Nodes
abstract class VbaStatement {}

class VbaAssignment extends VbaStatement {
  final String variable;
  final VbaExpression value;
  VbaAssignment(this.variable, this.value);
}

class VbaDimStatement extends VbaStatement {
  final String variable;
  final String? type;
  final VbaExpression? initialValue;
  VbaDimStatement(this.variable, this.type, this.initialValue);
}

class VbaIfStatement extends VbaStatement {
  final VbaExpression condition;
  final List<VbaStatement> thenBlock;
  final List<VbaElseIf>? elseIfBlocks;
  final List<VbaStatement>? elseBlock;
  VbaIfStatement(
    this.condition,
    this.thenBlock,
    this.elseIfBlocks,
    this.elseBlock,
  );
}

class VbaElseIf {
  final VbaExpression condition;
  final List<VbaStatement> body;
  VbaElseIf(this.condition, this.body);
}

class VbaForLoop extends VbaStatement {
  final String variable;
  final VbaExpression start;
  final VbaExpression end;
  final VbaExpression? step;
  final List<VbaStatement> body;
  VbaForLoop(this.variable, this.start, this.end, this.step, this.body);
}

class VbaWhileLoop extends VbaStatement {
  final VbaExpression condition;
  final List<VbaStatement> body;
  VbaWhileLoop(this.condition, this.body);
}

class VbaDoUntilLoop extends VbaStatement {
  final VbaExpression condition;
  final List<VbaStatement> body;
  VbaDoUntilLoop(this.condition, this.body);
}

class VbaDoWhileLoop extends VbaStatement {
  final VbaExpression condition;
  final List<VbaStatement> body;
  VbaDoWhileLoop(this.condition, this.body);
}

class VbaSelectCase extends VbaStatement {
  final VbaExpression expression;
  final List<VbaCase> cases;
  final List<VbaStatement>? defaultCase;
  VbaSelectCase(this.expression, this.cases, this.defaultCase);
}

class VbaCase {
  final List<VbaExpression> values;
  final List<VbaStatement> body;
  VbaCase(this.values, this.body);
}

class VbaWithStatement extends VbaStatement {
  final VbaExpression object;
  final List<VbaStatement> body;
  VbaWithStatement(this.object, this.body);
}

class VbaOnErrorStatement extends VbaStatement {
  final String label;
  VbaOnErrorStatement(this.label);
}

class VbaGoToStatement extends VbaStatement {
  final String label;
  VbaGoToStatement(this.label);
}

class VbaLabelStatement extends VbaStatement {
  final String label;
  VbaLabelStatement(this.label);
}

class VbaExitStatement extends VbaStatement {
  final String blockType;
  VbaExitStatement(this.blockType);
}

class VbaReturnStatement extends VbaStatement {
  final VbaExpression value;
  VbaReturnStatement(this.value);
}

class VbaSubDefinition extends VbaStatement {
  final String name;
  final List<String> parameters;
  final List<VbaStatement> body;
  VbaSubDefinition(this.name, this.parameters, this.body);
}

class VbaFunctionDefinition extends VbaStatement {
  final String name;
  final List<String> parameters;
  final List<VbaStatement> body;
  VbaFunctionDefinition(this.name, this.parameters, this.body);
}

class VbaComment extends VbaStatement {
  final String text;
  VbaComment(this.text);
}

// Expressions
abstract class VbaExpression {}

class VbaLiteral extends VbaExpression {
  final dynamic value;
  VbaLiteral(this.value);
}

class VbaVariable extends VbaExpression {
  final String name;
  VbaVariable(this.name);
}

class VbaBinaryExpression extends VbaExpression {
  final String operator;
  final VbaExpression left;
  final VbaExpression right;
  VbaBinaryExpression(this.operator, this.left, this.right);
}

class VbaUnaryExpression extends VbaExpression {
  final String operator;
  final VbaExpression operand;
  VbaUnaryExpression(this.operator, this.operand);
}

class VbaFunctionCall extends VbaExpression implements VbaStatement {
  final String name;
  final List<VbaExpression> arguments;
  VbaFunctionCall(this.name, this.arguments);
}

class VbaPropertyAccess extends VbaExpression {
  final VbaExpression object;
  final String property;
  VbaPropertyAccess(this.object, this.property);
}

class VbaMethodCall extends VbaExpression {
  final VbaExpression object;
  final String method;
  final List<VbaExpression> arguments;
  VbaMethodCall(this.object, this.method, this.arguments);
}

class VbaArrayAccess extends VbaExpression {
  final VbaExpression array;
  final VbaExpression index;
  VbaArrayAccess(this.array, this.index);
}

class VbaStringConcatenation extends VbaExpression {
  final VbaExpression left;
  final VbaExpression right;
  VbaStringConcatenation(this.left, this.right);
}

// Function wrapper
class VbaFunction {
  final dynamic Function(List<dynamic>) _impl;
  VbaFunction(this._impl);
  dynamic call(List<dynamic> args) => _impl(args);
}

// Error handling
class VbaErrorHandler {
  String? _currentHandler;

  void setHandler(String label) {
    _currentHandler = label;
  }

  void handleError(VbaRuntimeError error) {
    if (_currentHandler == 'ResumeNext') {
      // Resume on next line
    } else if (_currentHandler != null && _currentHandler!.isNotEmpty) {
      // Jump to error handler label
    } else {
      throw error;
    }
  }
}

class VbaRuntimeError implements Exception {
  final int number;
  final String description;
  final String? source;

  VbaRuntimeError(this.number, this.description, {this.source});

  @override
  String toString() => 'VBA Error $number: $description';
}

// PowerPoint-specific object model
class VbaPresentation {
  final Map<String, dynamic> properties = {};
  final List<Map<String, dynamic>> slides = [];

  Map<String, dynamic> toMap() => {'Slides': slides, ...properties};
}

class VbaSlide {
  final Map<String, dynamic> properties = {};
  final List<Map<String, dynamic>> shapes = [];

  Map<String, dynamic> toMap() => {'Shapes': shapes, ...properties};
}

class VbaShape {
  final Map<String, dynamic> properties = {};

  Map<String, dynamic> toMap() => properties;
}
