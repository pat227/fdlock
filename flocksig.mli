module type Flocksig = sig   
  type t = Flock_t.t
  val create: string -> t
  val acquire: t -> bool
  val release: t -> unit
end 
