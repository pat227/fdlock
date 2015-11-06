module type Flocksig = sig   
    type t = {
      pid:int;
      localhostname:string;
      acquired_dt:string;
      path:string;
      status:string
    }
    val pp : Format.formatter -> t -> unit
    val show : t -> string
    val to_yojson : t -> Yojson.Safe.json
    val of_yojson : Yojson.Safe.json -> [ `Error of string | `Ok of t ]
    val create: string -> t
    val acquire: t -> int option -> bool
    val release: t -> unit
end 
