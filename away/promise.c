#include "promise.h"
#include "../away.h"
#include <lauxlib.h>
#include <lua.h>
#include <stdnoreturn.h>
#include <time.h>

LUA_API noreturn int luaL_error(lua_State *L, const char *fmt, ...);
LUA_API noreturn int lua_error(lua_State *L);
LUA_API noreturn int luaL_typeerror(lua_State *L, int arg, const char *tname);

static const char *awayP_TAG = "away.promise";

enum awayP_status {
  awayP_EMPTY,
  awayP_OK,
  awayP_ERR,
};

struct awayP {
  enum awayP_status status;
};

LUA_API void awayP_new(lua_State *S) {
  struct awayP *promise = lua_newuserdatauv(S, sizeof(struct awayP), 2);
  *promise = (struct awayP){.status = awayP_EMPTY};
  luaL_setmetatable(S, awayP_TAG);
  lua_pushnil(S);
  lua_setiuservalue(S, -2, 1);
  lua_newtable(S);
  lua_setiuservalue(S, -2, 2);
}

LUA_API bool awayP_fulfilledp(lua_State *S, int idx) {
  struct awayP *p = lua_touserdata(S, idx);
  return p->status != awayP_EMPTY;
}

/**
 * @brief set promise value and wake threads. [-0, +0, e]
 *
 * @param S
 * @param idx
 * @param status
 */
static void awayP_set_value(lua_State *S, int idx, enum awayP_status status) {
  idx = idx < 0 ? lua_absindex(S, idx) : idx;
  struct awayP *p = lua_touserdata(S, idx);
  lua_pushvalue(S, -1);
  lua_setiuservalue(S, idx, 1);
  p->status = status;
  lua_getiuservalue(S, idx, 2);
  lua_Integer len = luaL_len(S, -1);
  for (lua_Integer i = 1; i <= len; i++) {
    if (lua_geti(S, -1, i) == LUA_TTHREAD) {
      lua_State *th = lua_tothread(S, -1);
      if (lua_status(th) == LUA_YIELD) {
        struct away_track *track = away_get_track(th);
        if (track == NULL) {
          luaL_error(
              track->S,
              "thread is waking from a promise, but not tracked by scheduler");
        }
        away_set_timer(track, &(struct timespec){.tv_sec = 0, .tv_nsec = 0});
      }
      lua_pop(S, 1);
    } else {
      luaL_error(S, "target #%d is not a thread", i);
    }
    lua_pop(S, 1);
  }
}

LUA_API void awayP_resolve(lua_State *S, int idx) {
  if (awayP_fulfilledp(S, idx)) {
    luaL_error(S, "promise had been fulfilled");
  }
  awayP_set_value(S, idx, awayP_OK);
}

LUA_API void awayP_reject(lua_State *S, int idx) {
  if (awayP_fulfilledp(S, idx)) {
    luaL_error(S, "promise had been fulfilled");
  }
  awayP_set_value(S, idx, awayP_ERR);
}

LUA_API int awayP_pwait(lua_State *S, lua_KContext kcx, lua_KFunction kfn) {
  struct awayP *p = lua_touserdata(S, -1);
  if (awayP_fulfilledp(S, -1)) {
    return LUA_OK;
  }
  lua_getiuservalue(S, -1, 2); /* +1 */
  lua_Integer i = luaL_len(S, -1);
  lua_pushthread(S);      /* +2 */
  lua_seti(S, -2, i + 1); /* +1 */
  lua_pop(S, 1);          /* 0 */
  if (awayP_fulfilledp(S, -1)) {
    return LUA_OK;
  }
  struct away_track *track = away_get_track(S);
  if (track == NULL) {
    luaL_error(S, "caller thread is not tracked by scheduler");
  }
  away_pause(track);
  return lua_yieldk(S, 0, 0, kfn);
}

static int awayP_waitc(lua_State *S, int status, lua_KContext kcx) {
  lua_KFunction kfn = lua_touserdata(S, -2);
  struct awayP *p = lua_touserdata(S, -1);
  switch (p->status) {
  case awayP_EMPTY:
    return lua_yieldk(S, 0, kcx, awayP_waitc);
  case awayP_OK:
    lua_insert(S, -2);
    lua_pop(S, 1);
    return kfn(S, status, kcx);
  case awayP_ERR:
    lua_insert(S, -2);
    lua_pop(S, 1);
    lua_getiuservalue(S, -1, 1);
    lua_error(S);
    return LUA_ERRERR;
  }
}

LUA_API int awayP_wait(lua_State *S, lua_KContext kcx, lua_KFunction kfn) {
  lua_pushlightuserdata(S, kfn);
  lua_insert(S, -2);
  int ret = awayP_pwait(S, kcx, awayP_waitc);
  return awayP_waitc(S, awayP_pwait(S, kcx, awayP_waitc), kcx);
}

static int lawayP_waitc(lua_State *S, int status, lua_KContext cx) {
  /* stack top is promise */
  struct awayP *p = lua_touserdata(S, -1);
  switch (p->status) {
  case awayP_OK:
    lua_getiuservalue(S, -1, 1);
    return 1;
  default:
    luaL_error(S, "unreachable");
  }
}

int lawayP_wait(lua_State *S) {
  struct awayP *p = luaL_checkudata(S, 1, awayP_TAG);
  return lawayP_waitc(S, awayP_wait(S, 0, lawayP_waitc),
                                0);
}

static int lawayP_new(lua_State *S) {
  awayP_new(S);
  return 1;
}

static int lawayP_fulfilledp(lua_State *S) {
  luaL_checkudata(S, 1, awayP_TAG);
  bool ret = awayP_fulfilledp(S, 1);
  lua_pushboolean(S, ret);
  return 1;
}

static int lawayP_resolve(lua_State *S) {
  luaL_checkudata(S, 1, awayP_TAG);
  awayP_resolve(S, 1);
  return 0;
}

static int lawayP_reject(lua_State *S) {
  luaL_checkudata(S, 1, awayP_TAG);
  awayP_reject(S, 1);
  return 0;
}

static int lawayP_pwaitc(lua_State *S, int status, lua_KContext kcx) {
  struct awayP *p = lua_touserdata(S, -1);
  switch (p->status) {
    case awayP_EMPTY:
    lua_yieldk(S, 0, 0, lawayP_pwaitc);
    luaL_error(S, "unreachable");
    break;
    case awayP_OK:
    lua_pushboolean(S, true);
    lua_getiuservalue(S, -2, 1);
    return 2;
    case awayP_ERR:
    lua_pushboolean(S, false);
    lua_getiuservalue(S, -2, 1);
    return 2;
  }
}

static int lawayP_pwait(lua_State *S) {
  luaL_checkudata(S, 1, awayP_TAG);
  return lawayP_pwaitc(S, awayP_pwait(S, 0, lawayP_pwaitc), 0);
}

static const luaL_Reg awayP_object[] = {
    {"wait", &lawayP_wait},
    {"pwait", &lawayP_pwait},
    {"fulfilledp", &lawayP_fulfilledp},
    {"resolve", &lawayP_resolve},
    {"reject", &lawayP_reject},
    {NULL, NULL},
};

static const luaL_Reg awayP_lib[] = {
    {"new", &lawayP_new},
    {"wait", &lawayP_wait},
    {"pwait", &lawayP_pwait},
    {"fulfilledp", &lawayP_fulfilledp},
    {"resolve", &lawayP_resolve},
    {"reject", &lawayP_reject},
    {NULL, NULL},
};

LUA_API int luaopen_away_promise(lua_State *S) {
  luaL_newmetatable(S, awayP_TAG);                                   /* +1 */
  lua_createtable(S, 0, (sizeof(awayP_lib) / sizeof(luaL_Reg)) - 1); /* +2 */
  luaL_setfuncs(S, awayP_object, 0);                                 /* +2 */
  lua_setfield(S, -2, "__index");                                    /* +1 */
  lua_pop(S, 1);                                                     /* 0 */
  luaL_newlib(S, awayP_lib);
  return 1;
}
