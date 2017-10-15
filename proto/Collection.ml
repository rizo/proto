
(** This module attempts to provide an uniform interface for {e collections}.

    The supported collections are:

    - Array
    - Bitmap
    - Bytes
    - Hashmap
    - Iterator
    - List
    - Map
    - Queue
    - Set
    - Stack
    - Stream
    - String
    - Vector
*)

open Kernel
open Control


type 'a iter =
  Iter : {
    init : 's;
    next : 'r . 's -> ('a -> 's -> 'r) -> 'r -> 'r
  } -> 'a iter


module Iter = struct
  type 'a t = 'a iter

  let each f (Iter i) =
    let rec go s =
      i.next s (fun a s' -> f a; go s') () in
    go i.init

  let fold_state s0 f r0 next =
    let rec go r s =
      next s (fun a -> go (f a r)) r in
    go r0 s0

  let fold f r (Iter i) =
    fold_state i.init f r i.next

  let reduce f (Iter i) =
    i.next i.init
      (fun r0 s0 -> Some (fold_state s0 f r0 i.next))
      None

  let fold_while f r0 (Iter i) =
    let rec go s r =
      i.next s
        (fun a s' ->
           match f a r with
           | `Continue r' -> go s' r'
           | `Stop r' -> r')
        r in
    go i.init r0

  let find predicate (Iter i) =
    let rec go s =
      i.next s
        (fun a s' ->
           if predicate a then Some a
           else go s')
        None in
    go i.init

  let find_index predicate (Iter i) =
    let rec go n s =
      i.next s
        (fun a s' ->
           if predicate a then Some n
           else go (n + 1) s')
        None in
    go 0 i.init

  let find_indices predicate (Iter i) =
    let rec go n r s =
      i.next s
        (fun a s' ->
           if predicate a then go (n + 1) (n :: r) s'
           else go (n + 1) r s') r in
    Stdlib.List.rev (go 0 [] i.init)

  let index ?equal x self =
    let equal = equal or Kernel.equal in
    find_index (equal x) self

  let indices ?equal x self =
    let equal = equal or Kernel.equal in
    find_indices (equal x) self

  let find_max ?by self =
    let compare = by or Kernel.compare in
    let (>) a b = compare a b = Comparable.greater in
    reduce (fun a b -> if a > b then a else b) self

  let find_min ?by self =
    let compare = by or Kernel.compare in
    let (<) a b = compare a b = Comparable.less in
    reduce (fun a b -> if a < b then a else b) self

  let contains x self =
    Option.is_some (find ((==) x) self)

  let count predicate (Iter i) =
    let rec go n s =
      i.next s
        (fun a s' ->
           if predicate a then go (n + 1) s'
           else go n s')
        n in
    go 0 i.init

  let sum self =
    fold ( + ) 0 self

  let product (Iter i) =
    let rec go r s =
      i.next s
        (fun a s' ->
           if a = 0 then 0
           else go (a * r) s')
        r in
    go 1 i.init

  let all p (Iter i) =
    let rec go s =
      i.next s
        (fun a s' ->
           if p a then go s'
           else false)
        true in
    go i.init

  let any p (Iter i) =
    let rec go s =
      i.next s
        (fun a s' ->
           if p a then go s'
           else true)
        false in
    go i.init

  let to_list_reversed self =
    fold (fun x xs -> x :: xs) [] self

  let to_list self =
    Stdlib.List.rev (to_list_reversed self)

  let is_empty (Iter i) =
    i.next i.init (fun _a _s -> false) true

  let length self =
    fold (fun _ n -> n + 1) 0 self

  let get n (Iter i) =
    let rec go idx s =
      i.next s
        (fun a s' ->
           if idx = n then Some a
           else go (idx + 1) s')
        None in
    go 0 i.init

  let first self  = get 0 self
  let second self = get 1 self

  let last self =
    fold (fun a _ -> Some a) None self
end


(* Should this be called sequential? For both array and list these functions
 * need to iterate the whole collection item by item, potentially stopping
 * early.
 * contains_index?
 *  - Complexity: O(n) *)
module type Iterable1 = sig
  type 'a t

  val each : ('a -> unit) -> 'a t -> unit

  val find: ('a -> bool) -> 'a t -> 'a option
  (** [find predicate self] returns the first leftmost element from [self]
      matching a given [predicate], or [None] if there is no such element.

      {[
        assert (List.find (fun a -> a < 0) [42; 21; 53; -2; 32] == Some (-2));
        assert (List.find (fun a -> a < 0) [42; 32; 21; 56; 34] == None);
      ]} *)

  val find_index : ('a -> bool) -> 'a t ->  int option
  (** [find_index predicate self] returns the index of the first leftmost
      element from [self] matching a given [predicate], or [None] if there is
      no such element.

      {[
        assert (List.find (fun a -> a < 0) [42; 21; 53; -2; 32] == Some 3);
        assert (List.find (fun a -> a < 0) [42; 32; 21; 56; 34] == None);
      ]} *)

  val find_indices : ('a -> bool) -> 'a t -> int list
  (** [find_indices p self] returns indices of all the elements from [self]
      matching the predicate [p]. *)

  val index : ?equal:('a -> 'a -> bool) -> 'a -> 'a t -> int option
  (** [index x self] searches for the item [x] in [self] and returns its index.

      {[
        assert (List.index 'b' ['a'; 'b'; 'c'; 'd'; 'e'] == Some 1);
        assert (List.index 'x' ['a'; 'b'; 'c'; 'd'; 'e'] == None);
      ]} *)

  val indices : ?equal:('a -> 'a -> bool) -> 'a -> 'a t -> int list
  (** [indices x self] searches for the item [x] in [self] and returns all its
      indices.

      {[
        assert (List.indices 'b' ['a'; 'b'; 'c'; 'b'; 'e'] == [1; 3]);
        assert (List.indices 'x' ['a'; 'b'; 'c'; 'd'; 'e'] == []);
      ]} *)

  val all : ('a -> bool) -> 'a t -> bool
  (** [all pred self] is [true] if all the elements from [self] match the
      predicate [pred]. *)

  val any : ('a -> bool) -> 'a t -> bool
  (** [any ppred self] is [true] if at least one element from [self] matches the
      predicate [pred]. *)

  val reduce : ('a -> 'a -> 'a) -> 'a t -> 'a option

  val find_min : ?by:('a -> 'a -> order) -> 'a t -> 'a option

  val find_max : ?by:('a -> 'a -> order) -> 'a t -> 'a option

  val sum : int t -> int
  (** [sum self] sums all integers in [self]. *)

  val product : int t -> int
  (** [product self] multiplies all integers in [self]. *)

  val contains : 'a -> 'a t -> bool
  (** [contains x self] is equivalent to [is_some (find ((=) x) self)].

      {[
        assert (contains 'x' ['a'; 'b'; 'x'] = true);
        assert (contains 'x' ['a'; 'b'; 'd'] = false);
      ]} *)


  val count : ('a -> bool) -> 'a t -> int
  (** [count predicate self] is [length (find predicate self)] but computed in
      one go.

      {[
        assert (count (fun a -> a < 0) [1; -2; 3; -4; 5; 6] == 2);
      ]} *)

  val fold : ('a -> 'r -> 'r) -> 'r -> 'a t -> 'r

  val fold_while : ('a -> 'b -> [< `Continue of 'b | `Stop of 'b ]) -> 'b -> 'a t -> 'b
  (** [fold_while predicate f b self] is like [fold] but stops the execution when
      [predicate] returns [false] on an item from [self].

      {[
        assert (List.fold_while (fun a b -> if a <= 3 then Continue a + b
                                  else Stop b) 0 [1; 2; 3; 4] = 6);
      ]} *)
end


module Iterable1 = struct
  module type Base = sig
    type 'a t
    type 'a state

    val init : 'a t -> 'a state
    val next : 'a t -> 'a state -> ('a -> 'a state -> 'r) -> 'r -> 'r
  end

  module Make(B : Base) : Iterable1 with type 'a t := 'a B.t = struct
    let iter self =
      Iter {
        init = B.init self;
        next = (fun s -> B.next self s)
      }

    let each f self                 = Iter.each f (iter self)
    let fold f r self               = Iter.fold f r (iter self)
    let fold_while f r self         = Iter.fold_while f r (iter self)
    let reduce f self               = Iter.reduce f (iter self)
    let find predicate self         = Iter.find predicate (iter self)
    let find_max ?by self           = Iter.find_max ?by (iter self)
    let find_min ?by self           = Iter.find_min ?by (iter self)
    let contains x self             = Iter.contains x (iter self)
    let index ?equal x self         = Iter.index ?equal x (iter self)
    let find_index predicate self   = Iter.find_index predicate (iter self)
    let find_indices predicate self = Iter.find_indices predicate (iter self)
    let indices ?equal x self       = Iter.indices ?equal x (iter self)
    let count predicate self        = Iter.count predicate (iter self)
    let sum self                    = Iter.sum (iter self)
    let product self                = Iter.product (iter self)
    let all predicate self          = Iter.all predicate (iter self)
    let any predicate self          = Iter.any predicate (iter self)
  end
end


module type Iterable0 = sig
  type t
  type item

  val find : (item -> bool) -> t -> item option
  val find_index : (item -> bool) -> t ->  int option
  val find_indices : (item -> bool) -> t -> int list
  val find_min : ?by:(item -> item -> order) -> t -> item option
  val find_max : ?by:(item -> item -> order) -> t -> item option
  val index : ?equal:(item -> item -> bool) -> item -> t -> int option
  val indices : ?equal:(item -> item -> bool) -> item -> t -> int list
  val all : (item -> bool) -> t -> bool
  val any : (item -> bool) -> t -> bool
  val reduce : (item -> item -> item) -> t -> item option
  val each : (item -> unit) -> t -> unit
  val contains : item -> t -> bool
  val count : (item -> bool) -> t -> int
  val fold_while : (item -> 'b -> [< `Continue of 'b | `Stop of 'b ]) -> 'b -> t -> 'b
  val fold : (item -> 'r -> 'r) -> 'r -> t -> 'r
end


module Iterable0 = struct
  module type Base = sig
    type t
    type item
    type state

    val init : t -> state
    val next : t -> state -> (item -> state -> 'r) -> 'r -> 'r
  end

  module Make(B : Base) : Iterable0 with type t := B.t and type item := B.item = struct
    let iter self =
      Iter {
        init = B.init self;
        next = (fun s -> B.next self s)
      }

    let each f self                 = Iter.each f (iter self)
    let fold f r self               = Iter.fold f r (iter self)
    let fold_while f r self         = Iter.fold_while f r (iter self)
    let reduce f self               = Iter.reduce f (iter self)
    let find predicate self         = Iter.find predicate (iter self)
    let find_max ?by self           = Iter.find_max ?by (iter self)
    let find_min ?by self           = Iter.find_min ?by (iter self)
    let contains x self             = Iter.contains x (iter self)
    let index ?equal x self         = Iter.index ?equal x (iter self)
    let find_index predicate self   = Iter.find_index predicate (iter self)
    let find_indices predicate self = Iter.find_indices predicate (iter self)
    let indices ?equal x self       = Iter.indices ?equal x (iter self)
    let count predicate self        = Iter.count predicate (iter self)
    let all predicate self          = Iter.all predicate (iter self)
    let any predicate self          = Iter.any predicate (iter self)
  end
end


module Indexable1 = struct
  module type Base = sig
    type 'a t

    val length : 'a t -> int
    val unsafe_get : int -> 'a t -> 'a
  end
end


module type Container1 = sig
  type 'a t

  val is_empty : 'a t -> bool
  (** [is_empty self] is [true] if [self] contains no elements.

      {[
        assert (List.is_empty [] == true);
        assert (String.is_empty "abc" == false);
      ]} *)

  val length : 'a t -> int
  (** [length self] counts the number of items in the list. *)

  val get : int -> 'a t -> 'a option
  (** [get n self] gets the [n]th element from [self] or None if [n] exceeds
      the length of [self].

      {b Note:} Negative indices are interpreted counting from the end of the
      collection.

      {[
        assert (get 1 [] = None);
        assert (get 1 ["a"; "b"; "c"] = Some "b");
        assert (get (-1) ["a"; "b"; "c"] = "c");
      ]} *)

  val first : 'a t -> 'a option

  val second : 'a t -> 'a option

  val last : 'a t -> 'a option
  (** [head self] is the first item of [self] or [None] if [self] is empty.

      {[
        assert (List.head [1; 2; 3] = Some 1);
        assert (List.head [] = None);
      ]} *)
end


module Container1 = struct
  module With_indexable(B : Indexable1.Base) : Container1 with type 'a t := 'a B.t = struct
    let is_empty self =
      match B.length self with
      | 0 -> true
      | n -> false

    let length = B.length

    let get i self =
      if i < B.length self then
        Some (B.unsafe_get i self)
      else
      None

    let first self  = get 0 self
    let second self = get 1 self

    let last self =
      get (length self - 1) self
  end

  module With_iterable(B : Iterable1.Base) : Container1 with type 'a t := 'a B.t = struct
    let iter self =
      Iter {
        init = B.init self;
        next = (fun s -> B.next self s)
      }

    let is_empty self = Iter.is_empty (iter self)
    let length self   = Iter.length (iter self)
    let get n self    = Iter.get n (iter self)
    let first self    = Iter.first (iter self)
    let second self   = Iter.second (iter self)
    let last self     = Iter.last (iter self)
  end
end


module Indexable0 = struct
  module type Base = sig
    type t
    type item

    val length : t -> int
    val unsafe_get : int -> t -> item
  end
end


module type Container0 = sig
  type t
  type item

  val is_empty : t -> bool
  (** [is_empty self] is [true] if [self] contains no elements.

      {[
        assert (List.is_empty [] == true);
        assert (String.is_empty "abc" == false);
      ]} *)

  val length : t -> int
  (** [length self] counts the number of items in the list. *)

  val get : int -> t -> item option
  (** [get n self] gets the [n]th element from [self] or None if [n] exceeds
      the length of [self].

      {b Note:} Negative indices are interpreted counting from the end of the
      collection.

      {[
        assert (get 1 [] = None);
        assert (get 1 ["a"; "b"; "c"] = Some "b");
        assert (get (-1) ["a"; "b"; "c"] = "c");
      ]} *)

  val first : t -> item option

  val second : t -> item option

  val last : t -> item option
  (** [head self] is the first item of [self] or [None] if [self] is empty.

      {[
        assert (List.head [1; 2; 3] = Some 1);
        assert (List.head [] = None);
      ]} *)
end


module Container0 = struct
  module With_indexable(B : Indexable0.Base) : Container0 with type t := B.t and type item := B.item = struct
    let is_empty self =
      match B.length self with
      | 0 -> true
      | n -> false

    let length = B.length

    let get i self =
      if i < B.length self then
        Some (B.unsafe_get i self)
      else
      None

    let first self  = get 0 self
    let second self = get 1 self

    let last self =
      get (length self - 1) self
  end

  module With_iterable(B : Iterable0.Base) : Container0 with type t := B.t = struct
    type item = B.item

    let iter self =
      Iter {
        init = B.init self;
        next = (fun s -> B.next self s)
      }

    let is_empty self = Iter.is_empty (iter self)
    let length self   = Iter.length (iter self)
    let get n self    = Iter.get n (iter self)
    let first self    = Iter.first (iter self)
    let second self   = Iter.second (iter self)
    let last self     = Iter.last (iter self)
  end
end


module type Iterable = Iterable1
module Iterable = Iterable1
module Indexable = Indexable1
module type Container = Container1
module Container = Container1

