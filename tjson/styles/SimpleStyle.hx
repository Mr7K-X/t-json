package tjson.styles;

using StringTools;

class SimpleStyle implements tjson.interfaces.EncodeStyle
{
  public function new() {}

  public function beginObject(depth:Int):String
    return "{";

  public function endObject(depth:Int):String
    return "}";

  public function beginArray(depth:Int):String
    return "[";

  public function endArray(depth:Int):String
    return "]";

  public function firstEntry(depth:Int):String
    return "";

  public function entrySeperator(depth:Int):String
    return ",";

  public function keyValueSeperator(depth:Int):String
    return ":";
}
