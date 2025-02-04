package tjson;

using StringTools;

class TJSON
{
  public static final OBJECT_REFERENCE_PREFIX = "@~obRef#";

  /**
   * Parses a JSON string into a haxe dynamic object or array.
   * @param String - The JSON string to parse
   * @param String the file name to whic the JSON code belongs. Used for generating nice error messages.
   */
  public static function parse<T:Dynamic>(json:String, ?fileName:String = "JSON Data", ?stringProcessor:String->T = null):T
    return new TJSONParser(json, fileName, stringProcessor).doParse();

  /**
   * Serializes a dynamic object or an array into a JSON string.
   * @param Dynamic - The object to be serialized
   * @param Dynamic - The style to use. Either an object implementing EncodeStyle interface or the strings 'fancy' or 'simple'.
   */
  public static function encode<T:Dynamic>(obj:T, ?style:Dynamic = null, useCache:Bool = true):String
    return new TJSONEncoder(useCache).doEncode(obj, style);
}
