#include <lua.h>
#include <stdbool.h>

/**
 * @brief Push new promise onto stack. [-0, +1, m]
 * 
 * @param S 
 * @return void 
 */
LUA_API void awayP_new(lua_State *S);

/**
 * @brief Check is the promise at `idx` fulfilled. [-0, +0, -]
 * 
 * @param S 
 * @param idx 
 * @return LUA_API 
 */
LUA_API bool awayP_fulfilledp(lua_State *S, int idx);

/**
 * @brief Resolve the promise at `idx` with the top of the stack. [-1, +0, e]
 * 
 * @param S 
 * @param idx 
 * @return void
 */
LUA_API void awayP_resolve(lua_State *S, int idx);

/**
 * @brief Reject the promise at `idx` with the top of the stack. [-1, +0, e]
 * 
 * @param S 
 * @return void 
 */
 LUA_API void awayP_reject(lua_State *S, int idx);

/**
 * @brief Protected wait for a promise at the stack top. [-0, +0, e]
 * If the promise is fulfilled, yield the thread and continue at `kfn`, like `lua_pcallk`.
 * The stack top is still the promise for this case.
 * This function may not yield but return `LUA_OK` if the promise is already fulfilled.
 *
 * This function can additionally raise errors in critical situation,
 * when the caller thread is not tracked by any scheduler ("caller thread is not tracked by scheduler")
 * 
 * @param S 
 * @param idx 
 * @param kcx 
 * @param kfn 
 * @return int
 */
LUA_API int awayP_pwait(lua_State *S, lua_KContext kcx, lua_KFunction kfn);

/**
 * @brief Just like `awayP_pwait`, but raise error instead of continue. [-0, +0, e]
 * 
 * @param S 
 * @return LUA_API 
 */
LUA_API int awayP_wait(lua_State *S, lua_KContext kcx, lua_KFunction kfn);

LUA_API int luaopen_away_promise(lua_State *S);
