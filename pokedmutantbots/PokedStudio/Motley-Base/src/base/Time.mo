import T "mo:base/Time";
import Int "mo:base/Int";
import Nat "mo:base/Nat";

module Time {

  public type Time = T.Time;

  public let now = T.now;

  public module Datetime {

    type Increments = (Nat,Nat,Nat,Nat);

    func _sec()  : Nat { 1000000000 };
    func _min()  : Nat { 60 * _sec() };
    func _hour() : Nat { 60 * _min() };
    func _day()  : Nat { 24 * _hour() }; 

    func increments( t : Time ) : Increments {
      var time : Nat = Int.abs(t);
      let days : Nat = time / _day();
      time := time % _day();
      let hours : Nat = time / _hour();
      time := time % _hour();
      let mins : Nat = time / _min();
      time := time % _min();
      let secs : Nat = time / _sec();
      (days,hours,mins,secs); 
    };

    func days_to_month( y : Nat, d : Nat ) : (Text, Nat) {
      var l : Nat = 0;
      if ( y % 4 == 0 ) l += 1;
      if ( d <= 31 ){ return ("01", d+1)};
      if ( d % ( 334 + l ) > 0 ){ return ("12", d % ( 334 + l) + 1)};
      if ( d % ( 304 + l ) > 0 ){ return ("11", d % ( 304 + l) + 1)};
      if ( d % ( 273 + l ) > 0 ){ return ("10", d % ( 273 + l) + 1)};
      if ( d % ( 243 + l ) > 0 ){ return ("09", d % ( 243 + l) + 1)};
      if ( d % ( 212 + l ) > 0 ){ return ("08", d % ( 212 + l) + 1)};
      if ( d % ( 181 + l ) > 0 ){ return ("07", d % ( 181 + l) + 1)};
      if ( d % ( 151 + l ) > 0 ){ return ("06", d % ( 151 + l) + 1)};
      if ( d % ( 120 + l ) > 0 ){ return ("05", d % ( 120 + l) + 1)};
      if ( d % ( 90 + l ) > 0 ){ return ("04", d % ( 90 + l) + 1)};
      if ( d % ( 59 + l ) > 0 ){ return ("03", d % ( 59 + l) + 1)};
      if ( d % ( 31 ) > 0 ){ return ("02", d % ( 333 + l) + 1)};
      ("01",1);
    };

    public func now() : Text {
      let inc : Increments = increments( Time.now() );
      var rem_days : Nat = inc.0;
      var year : Nat = 1970;
      label l loop {
        if ( (year % 4) > 0 and rem_days < 365 ) break l;
        if ( (year % 4) == 0 and rem_days < 366 ) break l;
        if ( (year % 4) > 0 ) { rem_days -= 365; year += 1 };
        if ( (year % 4) == 0 ) { rem_days -= 366; year += 1 };
      };
      let (month, d) = days_to_month(year, rem_days);
      let day : Text = Nat.toText(d);
      let hours : Text = Nat.toText(inc.1);
      let mins : Text = Nat.toText(inc.2);
      let secs : Text = Nat.toText(inc.3);
      Nat.toText(year) # "-" # month # "-" # day # ", " # hours # ":" # mins # ":" # secs;
    };

  };

};