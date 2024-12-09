import Text "Text";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";


module {

  // The HTML type is used throughout this module to help identify where formatted text is expected as input/outout
  public type HTML = Text;
  public type Scope = { #Row; #Col };

  let _html_body : HTML = "<!DOCTYPE html><html><body><<BODY>></body></html>";
  let _html_table : HTML = "<table><<DATA>></table>";
  let _html_table_caption : HTML = "<caption><<CAPTION>></caption>";
  let _html_w_header : HTML = "<!DOCTYPE html><html><body><h2><<HEADER>></h2><<BODY>></body></html>";  
  let _html_w_style_and_header : HTML = "<!DOCTYPE html><html><style><<STYLE>></style><body><h2><<HEADER>></h2><<BODY>></body></html>";
  let _video_template : HTML = "<center><video autoplay controls loop muted height=\"<<HEIGHT>>\" width=\"<<WIDTH>>\"><source src=\"<<SRC>>\" type=\"<<TYPE>>\"></video></center>";
  let _href : HTML = "<p><a href=\"<<URL>>\"><<DISPLAY>></a></p>";

  public func html_simple() : HTML { _html_body };

  public func html_w_header( header : Text ) : HTML {
    Text.replace(_html_w_header, #text("<<HEADER>>"), header);
  };

  public func wrap_document( d : HTML ) : HTML {
    "<!DOCTYPE html><html>" # d # "</html>";
  };

  public func style_elements( s : [(Text,[(Text,Text)])] ) : HTML {
    let elements = Buffer.Buffer<Text>(s.size());
    for ( elem in s.vals() ) {
      let attributes = Buffer.Buffer<Text>(elem.1.size());
      for ( attr in elem.1.vals() ) {
        attributes.add(attr.0 # ":" # attr.1 # ";");
      };
      elements.add(elem.0 # "{" # Text.join("",attributes.vals()) # "}");
    };
    Text.join("", elements.vals());
  };

  public func wrap_element( t : Text, d : HTML ) : HTML {
    "<"#t#">"#d#"</"#t#">";
  };

  public func table_row_scoped( h : [Text], scope : Scope ) : HTML {
    let buff = Buffer.fromArray<Text>(["<tr>"]);
    switch ( scope ) {
      case ( #Row ) {
        buff.add( "<th scope=\"row\">" # h[0] # "</th>" );
        for ( i in Iter.range(1, (h.size() - 1)) ) {
          buff.add( "<th>" # h[i] # "</th>" );
        };
      };
      case ( #Col ) {
        for ( entry in h.vals() ) {
          buff.add( "<th scope=\"col\">" # entry # "</th>" );
        };
      };
    };
    buff.add("</tr>");
    Text.join("", buff.vals());
  };

  public func table_row_plain( d : [Text] ) : HTML {
    let buff = Buffer.Buffer<Text>(0);
    buff.add("<tr>");
    for ( data in d.vals() ){
      buff.add("<td>"#data#"</td>");
    };
    buff.add("</tr>");
    Text.join("", buff.vals());
  };

  public func table_row_colored( d : [Text], color : Text ) : HTML {
    let buff = Buffer.Buffer<Text>(0);
    buff.add("<tr>");
    for ( data in d.vals() ){
      buff.add("<td bgcolor=\""#color#"\">"#data#"</td>");
    };
    buff.add("</tr>");
    Text.join("", buff.vals());
  };

  public func html_stylized( header : Text, style : HTML ) : HTML {
    var ret : HTML = Text.replace(_html_w_style_and_header, #text("<<HEADER>>"), header);
    Text.replace(ret, #text("<<STYLE>>"), style);
  };

  public func href( url : Text, display : Text ) : HTML {
    var ret : HTML = Text.replace(_href, #text("<<URL>>"), url);
    Text.replace(ret, #text("<<DISPLAY>>"), display);
  };

  public func add_body_elements( html : HTML, body : Text ) : HTML {
    Text.replace(html, #text("<<BODY>>"), body);
  };

  public func video_element( src : Text, ctype : Text, width : ?Text, height : ?Text ) : HTML {
    let w : Text = Option.get(width, "1920");
    let h : Text = Option.get(height, "1080");
    var ret : Text = Text.replace(_video_template, #text("<<HEIGHT>>"), h);
    ret := Text.replace(ret, #text("<<WIDTH>>"), w);
    ret := Text.replace(ret, #text("<<SRC>>"), src);
    Text.replace(ret, #text("<<TYPE>>"), ctype);
  };

}