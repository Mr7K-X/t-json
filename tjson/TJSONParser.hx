package tjson;

using StringTools;

/**
 * Class for `TJSON.parse()`. Used for parsing a project system files or something.
 */
class TJSONParser
{
  var pos:Int;
  var json:String;
  var lastSymbolQuoted:Bool;
  var fileName:String;
  var currentLine:Int;
  var cache:Array<Dynamic>;
  var floatRegex:EReg;
  var intRegex:EReg;
  var strProcessor:String->Dynamic;

  /**
   * Creating a json parser for `doParse()` calling function.
   */
  public function new<T:Dynamic>(json:String, ?fileName:String = "JSON Data", ?stringProcessor:String->T = null):Void
  {
    this.json = json;
    this.fileName = fileName;
    this.currentLine = 1;
    this.lastSymbolQuoted = false;
    this.pos = 0;
    this.floatRegex = _defaultFloatReg;
    this.intRegex = _defaultIntReg;
    this.strProcessor = (stringProcessor == null ? _defaultStrProcess : stringProcessor);
    this.cache = new Array();
  }

  /**
   * Parsing a current json file data for project.
   * @return Current `typedef` or something else data.
   */
  public function doParse<T:Dynamic>():T
  {
    try
    {
      return switch (getNextSymbol())
      {
        case '{': doObject();
        case '[': doArray();
        case s: convertSymbolToProperType(s);
      }
    }
    catch (e:haxe.Exception)
      throw fileName + " on line " + currentLine + ": " + e.message;
  }

  private function doObject():Dynamic
  {
    var o:Dynamic = {};
    var val:Dynamic = '';
    var key:String;
    var isClassOb:Bool = false;

    this.cache.push(o);

    while (pos < json.length)
    {
      key = getNextSymbol();

      if (key == "," && !lastSymbolQuoted) continue;
      if (key == "}" && !lastSymbolQuoted)
      {
        if (isClassOb && #if flash9 try o.TJ_unserialize != null catch (e:Dynamic) false #elseif (cs || java) Reflect.hasField(o,
          "TJ_unserialize") #else o.TJ_unserialize != null #end) o.TJ_unserialize();

        return o;
      }

      final seperator = getNextSymbol();
      if (seperator != ":") throw("Expected ':' but got '" + seperator + "' instead.");

      final v = getNextSymbol();

      if (key == '_hxcls')
      {
        final cls = Type.resolveClass(v);
        if (cls == null) throw "Invalid class name - " + v;
        o = Type.createEmptyInstance(cls);
        cache.pop();
        cache.push(o);
        isClassOb = true;
        continue;
      }

      if (v == "{" && !lastSymbolQuoted) val = doObject();
      else if (v == "[" && !lastSymbolQuoted) val = doArray();
      else
        val = convertSymbolToProperType(v);

      Reflect.setField(o, key, val);
    }

    throw "Unexpected end of file. Expected '}'";
  }

  private function doArray():Dynamic
  {
    var a:Array<Dynamic> = new Array<Dynamic>();
    var val:Dynamic;

    while (pos < json.length)
    {
      val = getNextSymbol();

      if (val == ',' && !lastSymbolQuoted) continue;
      else if (val == ']' && !lastSymbolQuoted) return a;
      else if (val == "{" && !lastSymbolQuoted) val = doObject();
      else if (val == "[" && !lastSymbolQuoted) val = doArray();
      else
        val = convertSymbolToProperType(val);

      a.push(val);
    }

    throw "Unexpected end of file. Expected ']'";
  }

  private function convertSymbolToProperType(symbol:Dynamic):Dynamic
  {
    if (lastSymbolQuoted)
    {
      if (StringTools.startsWith(Std.string(symbol), TJSON.OBJECT_REFERENCE_PREFIX))
      {
        var idx:Int = Std.parseInt(Std.string(symbol).substr(TJSON.OBJECT_REFERENCE_PREFIX.length));
        return cache[idx];
      }
      return symbol;
    }

    if (looksLikeFloat(symbol)) return Std.parseFloat(symbol);
    if (looksLikeInt(symbol)) return Std.parseInt(symbol);
    if (symbol.toLowerCase() == "true") return true;
    if (symbol.toLowerCase() == "false") return false;
    if (symbol.toLowerCase() == "null") return null;

    return symbol;
  }

  private function getNextSymbol()
  {
    this.lastSymbolQuoted = false;

    var c:String = '';
    var inQuote:Bool = false;
    var quoteType:String = "";
    var symbol:String = '';
    var inEscape:Bool = false;
    var inSymbol:Bool = false;
    var inLineComment = false;
    var inBlockComment = false;

    while (pos < json.length)
    {
      c = json.charAt(pos++);
      if (c == "\n" && !inSymbol) currentLine++;
      if (inLineComment)
      {
        if (c == "\n" || c == "\r")
        {
          inLineComment = false;
          pos++;
        }
        continue;
      }

      if (inBlockComment)
      {
        if (c == "*" && json.charAt(pos) == "/")
        {
          inBlockComment = false;
          pos++;
        }
        continue;
      }

      if (inQuote)
      {
        if (inEscape)
        {
          inEscape = false;
          if (c == "'" || c == '"')
          {
            symbol += c;
            continue;
          }
          if (c == "t")
          {
            symbol += "\t";
            continue;
          }
          if (c == "n")
          {
            symbol += "\n";
            continue;
          }
          if (c == "\\")
          {
            symbol += "\\";
            continue;
          }
          if (c == "r")
          {
            symbol += "\r";
            continue;
          }
          if (c == "/")
          {
            symbol += "/";
            continue;
          }

          if (c == "u")
          {
            var hexValue = 0;

            for (i in 0...4)
            {
              if (pos >= json.length) throw "Unfinished UTF8 character";
              var nc = json.charCodeAt(pos++);
              hexValue = hexValue << 4;
              if (nc >= 48 && nc <= 57) hexValue += nc - 48;
              else if (nc >= 65 && nc <= 70) hexValue += 10 + nc - 65;
              else if (nc >= 97 && nc <= 102) hexValue += 10 + nc - 95;
              else
                throw "Not a hex digit";
            }

            #if !neko
            final utf = new UnicodeString(Std.string(hexValue));
            symbol += utf.toString();
            #else
            symbol += Std.string(hexValue);
            #end

            continue;
          }

          throw "Invalid escape sequence '\\" + c + "'";
        }
        else
        {
          if (c == "\\")
          {
            inEscape = true;
            continue;
          }
          if (c == quoteType) return symbol;
          symbol += c;
          continue;
        }
      }
      else if (c == "/")
      {
        var c2 = json.charAt(pos);
        if (c2 == "/")
        {
          inLineComment = true;
          pos++;
          continue;
        }
        else if (c2 == "*")
        {
          inBlockComment = true;
          pos++;
          continue;
        }
      }

      if (inSymbol)
      {
        if (c == ' ' || c == "\n" || c == "\r" || c == "\t" || c == ',' || c == ":" || c == "}" || c == "]")
        {
          pos--;
          return symbol;
        }
        else
        {
          symbol += c;
          continue;
        }
      }
      else
      {
        if (c == ' ' || c == "\t" || c == "\n" || c == "\r") continue;
        if (c == "{" || c == "}" || c == "[" || c == "]" || c == "," || c == ":") return c;
        if (c == "'" || c == '"')
        {
          inQuote = true;
          quoteType = c;
          lastSymbolQuoted = true;
          continue;
        }
        else
        {
          inSymbol = true;
          symbol = c;
          continue;
        }
      }
    }

    if (inQuote) throw "Unexpected end of data. Expected ( " + quoteType + " )";
    return symbol;
  }

  private function looksLikeFloat(s:String):Bool
    return floatRegex.match(s) || (intRegex.match(s) &&
      {
        var intStr = intRegex.matched(0);
        if (intStr.charCodeAt(0) == "-".code) intStr > "-2147483648";
        else
          intStr > "2147483647";
      });

  private function looksLikeInt(s:String):Bool
    return intRegex.match(s);

  private final _defaultFloatReg:EReg = ~/^-?[0-9]*\.[0-9]+$/;
  private final _defaultIntReg:EReg = ~/^-?[0-9]+$/;

  private function _defaultStrProcess(str:String):Dynamic
    return str;
}
