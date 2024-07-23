import type * as Stream from "../Stream.js";
export declare const raceAll: <S extends ReadonlyArray<Stream.Stream<any, any, any>>>(...streams: S) => Stream.Stream<Stream.Stream.Success<S[number]>, Stream.Stream.Error<S[number]>, Stream.Stream.Context<S[number]>>;
declare const void_: Stream.Stream<void>;
export { 
/** @internal */
void_ as void };
export declare const zipLatestAll: <T extends ReadonlyArray<Stream.Stream<any, any, any>>>(...streams: T) => Stream.Stream<[T[number]] extends [never] ? never : { [K in keyof T]: T[K] extends Stream.Stream<infer A, infer _E, infer _R> ? A : never; }, [T[number]] extends [never] ? never : T[number] extends Stream.Stream<infer _A, infer _E_1, infer _R_1> ? _E_1 : never, [T[number]] extends [never] ? never : T[number] extends Stream.Stream<infer _A, infer _E_2, infer _R_2> ? _R_2 : never>;
//# sourceMappingURL=stream.d.ts.map