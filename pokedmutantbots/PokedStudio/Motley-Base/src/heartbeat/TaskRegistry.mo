import Trie "mo:base/Trie";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import List "mo:base/List";
import Option "mo:base/Option";
import HB "Types";
import TL "TaskList";
import Common "../../../Motley/src/Common";

module {

  private type Interval = HB.Interval;
  private type Task = HB.Task;
  private type TaskList = TL.TaskList;
  private type StableTasks = TL.StableTasks;

  public type TaskRegistry = Trie.Trie<Common.ActorTag,TaskList>;

  public func empty() : TaskRegistry {Trie.empty<Common.ActorTag,TaskList>()};

  public func put(map : TaskRegistry, svc : Common.ActorTag, list : TaskList ) : TaskRegistry {
    Trie.put<Common.ActorTag, TaskList>(map, Common.ActorTag.key(svc), Common.ActorTag.equal, list).0;
  };

  public func tasks_by_svc_interval(map : TaskRegistry, svc : Common.ActorTag, interval : Interval ) : Iter.Iter<Task> {
    switch( Trie.get<Common.ActorTag,TaskList>(map, Common.ActorTag.key(svc), Common.ActorTag.equal) ){
      case(?tl){ TL.tasks_by_interval(tl, interval) };
      case(_){ Iter.fromArray([]) };
    };
  };

};