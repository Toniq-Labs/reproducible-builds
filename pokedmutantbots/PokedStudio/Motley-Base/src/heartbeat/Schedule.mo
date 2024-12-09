import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import List "mo:base/List";
import Option "mo:base/Option";
import HB "Types";
import AS "../../../Motley/src/messaging/ActorSet";
import Common "../../../Motley/src/Common";

module {

  private type Interval = HB.Interval;
  private type ActorSet = AS.ActorSet;
  public type Schedule = Trie.Trie<Interval,ActorSet>;

  public func empty() : Schedule {Trie.empty<Interval,ActorSet>()};

  public func add(map : Schedule, interval : Interval, svc : Common.ActorTag ) : Schedule {
    var aset : ActorSet = Option.get(Trie.get<Interval,ActorSet>(
      map, HB.Interval.key(interval), HB.Interval.equal), AS.init());
    aset := AS.put(aset, svc);
    Trie.put<Interval,ActorSet>(map, HB.Interval.key(interval), HB.Interval.equal, aset).0;
  };

  public func services_by_interval(map : Schedule, interval : Interval ) : Iter.Iter<Common.ActorTag> {
    let aset : ActorSet = Option.get(Trie.get<Interval,ActorSet>(
      map, HB.Interval.key(interval), HB.Interval.equal), AS.init());
    Iter.fromArray( AS.toArray(aset) );
  };

  public func intervals( map : Schedule ) : Iter.Iter<Interval> {
    Iter.map(entries(map), func (kv : (Interval, ActorSet)) : Interval { kv.0 });
  };

  public func entries( map : Schedule ) : Iter.Iter<(Interval, ActorSet)> {
    object {
      var stack = ?(map, null) : List.List<Trie.Trie<Interval, ActorSet>>;
      public func next() : ?(Interval, ActorSet) {
        switch stack {
          case null { null };
          case (?(trie, stack2)) {
            switch trie {
              case (#empty) {
                stack := stack2;
                next()
              };
              case (#leaf({keyvals = null})) {
                stack := stack2;
                next()
              };
              case (#leaf({size = c; keyvals = ?((k, v), kvs)})) {
                stack := ?(#leaf({size=c-1; keyvals=kvs}), stack2);
                ?(k.key, v)
              };
              case (#branch(br)) {
                stack := ?(br.left, ?(br.right, stack2));
                next()
              };
            };
          };
        };
      };
    };
  };

};