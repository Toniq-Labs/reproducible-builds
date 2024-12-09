import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";

module {

  public type Path = Text;
  public type Elements = Iter.Iter<Text>;
  public let Root : Text = "/";

  let _raw : Text = "https://<<PRINCIPAL>>.raw.ic0.app";
  let _localhost : Text = "http://<<PRINCIPAL>>.localhost:8000";
  let _href : Text = "<p><a href=\"<<URL>>\"><<DISPLAY>></a></p>";
  let _html : Text = "<!DOCTYPE html><html><style><<STYLE>></style><body><h2><<HEADER>></h2><<BODY>></body></html>";
  let _video : Text = "<video></video>";

  public func is_valid( path : Path ) : Bool {
    Text.startsWith(path, #char('/'));
  };

  public func is_root( path : Path ) : Bool {
    Text.equal(path, Root);
  };

  public func index( path : Path, index : Nat ) : ?Text {
    let elems : [Text] = Iter.toArray(elements(path));
    if ( elems.size() > index ){
      return ?elems[index];
    };
    null;
  };

  public func html_with_header( header : Text ) : Text {
    Text.replace(_html, #text("<<HEADER>>"), header);
  };

  public func href( url : Text, handle : Text ) : Text {
    Text.replace(Text.replace(_href, #text("<<URL>>"), url), #text("<<DISPLAY>>"), handle);
  };

  public func from_url( url : Text, p : Principal ) : ?Path {
    var template : Text = "";
    if ( Text.contains(url, #text("localhost")) ){ template := _raw
    } else { template := _raw };
    let head : Text = Text.replace(template, #text("<<PRINCIPAL>>"), Principal.toText(p));
    Text.stripStart(url, #text(head));
  };

  public func to_url( path : Path, p: Principal ) : Text {
    let head : Text = Text.replace(_raw, #text("<<PRINCIPAL>>"), Principal.toText(p));
    head # path;
  };

  public func join( p1 : Path, p2 : Path ) : Path {
    var head : Path = p1;
    if ( Text.startsWith(head, #text("/")) == false){ head := "/" # head };
    if ( Text.endsWith(head, #text("/")) == false ){ head #= "/" };
    let tail : Path = Option.get(Text.stripStart(p2, #text("/")), p2);
    head # tail;
  };

  public func depth( path : Path ) : Nat {
    var count : Int = -1;
    for ( i in elements(path) ){
      count += 1;
    };
    Int.abs(count);
  };

  public func dirname( path : Path ) : Path {
    assert is_valid(path);
    if ( is_root(path) ) return Root;
    let elems : [Text] = Iter.toArray<Text>(elements(path));
    Option.get(Text.stripEnd( path, #text(elems[elems.size()-1])), Root);
  };

  public func basename( path : Path ) : Text {
    if ( is_valid(path) ){
      switch( Buffer.fromIter<Text>(elements(path)).removeLast() ){
        case( null ){ path };
        case( ?some ){ some };
      };
    } else {
      switch( Buffer.fromIter<Text>(Text.split(path, #text("/"))).removeLast() ){
        case null path;
        case ( ?some ) some
      }
    };
  };

  public func elements( path : Path ) : Elements {
    if ( is_root(path) ){ return Iter.fromArray([]) };
    var to_split : Text = "none";
    if ( is_valid(path) ){       
      switch( Text.stripStart(path, #text("/")) ){
        case( ?lstripped ){
          switch( Text.stripEnd(lstripped, #text("/")) ){
            case( ?rstripped ){ to_split := rstripped };
            case( null ){ to_split := lstripped };
        }};
        case( null ){};
      };
    } else { return Iter.fromArray([path]) };
    Text.split(to_split, #text("/"));
  };

  public func from_elements( elems : Elements ) : Path {
    "/" # Text.join("/", elems);
  };

  public func parent_elements( path : Path ) : Elements {
    elements( dirname(path) );
  };

};