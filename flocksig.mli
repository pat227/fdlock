module type Flocksig = sig   
  type t = Flock_t.t
  val create: string -> t
  val acquire: t -> int option -> bool
  val release: t -> unit
end 
