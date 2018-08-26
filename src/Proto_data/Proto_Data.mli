
module Array : sig
  type 'a t = 'a array

  val of_list : 'a list -> 'a t

  module Unsafe : sig
    val get : int -> 'a array -> 'a
  end

  include Monoid      with type 'a t := 'a t
  include Default1    with type 'a t := 'a t
  include Functor     with type 'a t := 'a t
  include Iterable    with type 'a t := 'a t
  include Collectable with type 'a t := 'a t
end
