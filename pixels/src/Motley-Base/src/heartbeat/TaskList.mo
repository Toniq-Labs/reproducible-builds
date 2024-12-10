import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import List "mo:base/List";
import Option "mo:base/Option";
import HB "Types";

module {

  private type Interval = HB.Interval;
  private type Task = HB.Task;
  public type TaskList = Trie.Trie<Interval, [Task]>;
  public type StableTasks = [(Interval,[Task])];

  public func empty() : TaskList {Trie.empty<Interval, [Task]>()};
  
  public func schedule_task(map : TaskList, sched : HB.ScheduledTask ) : TaskList {
    let interval : Interval = sched.interval;
    let current : [Task] = Option.get(Trie.get(map, HB.Interval.key(interval), HB.Interval.equal), []);
    let buff = Buffer.fromArray<HB.Task>(current);
    for ( task in sched.tasks.vals() ){ buff.add(task) };
    Trie.put<Interval,[Task]>(map, HB.Interval.key(interval), HB.Interval.equal, buff.toArray()).0;
  };

  public func intervals( map : TaskList ) : Iter.Iter<Interval> {
    Iter.map(entries(map), func (kv : (Interval, [Task])) : Interval { kv.0 });
  };

  public func stable_entries( map : TaskList ) : StableTasks {
    Iter.toArray(entries(map));
  };

  public func from_stable( stable_entries : StableTasks ) : TaskList {
    var task_list : TaskList = empty();
    for ( task_set in stable_entries.vals() ){
      task_list := Trie.put<Interval,[Task]>(task_list, HB.Interval.key(task_set.0), HB.Interval.equal, task_set.1).0;
    };
    return task_list;
  };

  public func tasks_by_interval( map : TaskList, x : Interval ) : Iter.Iter<Task> {
    Iter.fromArray( Option.get( Trie.get<Interval,[Task]>(map, HB.Interval.key(x), HB.Interval.equal), [] ) );
  };

  public func entries( map : TaskList ) : Iter.Iter<(Interval, [Task])> {
    object {
      var stack = ?(map, null) : List.List<Trie.Trie<Interval, [Task]>>;
      public func next() : ?(Interval, [Task]) {
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