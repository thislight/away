#include "away.h"
#include <assert.h>
#include <float.h>
#include <lauxlib.h>
#include <limits.h>
#include <lauxlib.h>
#include <lua.h>
#include <stdnoreturn.h>

static_assert(LUA_EXTRASPACE >= sizeof(struct away_track *),
              "LUA_EXTRASPACE must able to store a pointer");

static_assert(sizeof(void *) >= sizeof(int),
              "Pointer must be able to store an int");

LUA_API noreturn int luaL_error(lua_State *L, const char *fmt, ...);
LUA_API noreturn int lua_error(lua_State *L);
LUA_API noreturn int luaL_typeerror(lua_State *L, int arg, const char *tname);

enum away_thread_status {
  AWAY_TH_RUN,
  AWAY_TH_DEAD,
  AWAY_TH_YIELD,
  AWAY_TH_NORMAL,
};

void awayI_free(lua_State *S, void *ptr, size_t osize) {
  if (ptr != NULL) {
    void *ud = NULL;
    lua_Alloc alloc = lua_getallocf(S, &ud);
    alloc(ud, ptr, osize, 0);
  }
}

void *awayI_realloc(lua_State *S, void *ptr, size_t osize, size_t new_size) {
  void *ud = NULL;
  lua_Alloc alloc = lua_getallocf(S, &ud);
  void *nptr = alloc(ud, ptr, osize, new_size);
  return nptr;
}

struct away_track **awayI_get_track_store(lua_State *th) {
  return lua_getextraspace(th);
}

struct away_tracklist awayI_tracklist_empty() {
  return (struct away_tracklist){
      .items = NULL,
      .size = 0,
      .len = 0,
  };
}

/**
 * @brief Update track pointers in lua_States.
 * Call this function with the moved memory, or away calls will fail.
 *
 * @param olist
 * @param nptr
 */
void awayI_tracklist_update_ptrs(struct away_tracklist *olist,
                                 struct away_track *nptr) {
  for (size_t i = 0; i < olist->len; i++) {
    struct away_track *track = &nptr[i];
    *awayI_get_track_store(track->S) = track;
  }
}

int awayI_tracklist_expand(lua_State *S, struct away_tracklist *list,
                           size_t nel) {
  size_t nsize = nel + list->size;
  struct away_track *nptr =
      awayI_realloc(S, list->items, list->size * sizeof(struct away_track),
                    nsize * sizeof(struct away_track));
  if (nptr != NULL) {
    if (nptr != list->items) {
      awayI_tracklist_update_ptrs(list, nptr);
    }
    list->items = nptr;
    list->size = nsize;
    return LUA_OK;
  } else {
    return LUA_ERRMEM;
  }
}

int awayI_tracklist_shrink(lua_State *S, struct away_tracklist *list,
                           size_t left_el) {
  size_t nsize = list->len + left_el;
  void *nptr =
      awayI_realloc(S, list->items, list->size * sizeof(struct away_track),
                    nsize * sizeof(struct away_track));
  if (nptr != NULL) {
    if (nptr != list->items) {
      awayI_tracklist_update_ptrs(list, nptr);
    }
    list->items = nptr;
    list->size = nsize;
    return LUA_OK;
  } else {
    return LUA_ERRMEM;
  }
}

int awayI_tracklist_ensure_capacity(lua_State *S, struct away_tracklist *list,
                                    size_t nel) {
  size_t size = list->size;
  size_t new_len = list->len + nel;
  if (size < new_len) {
    size_t required_n = nel - (size - list->len) + 1;
    return awayI_tracklist_expand(S, list, required_n);
  } else if ((size / 2) > new_len) {
    awayI_tracklist_shrink(S, list, nel);
    return LUA_OK;
  } else {
    return LUA_OK;
  }
}

struct away_track *awayI_tracklist_geti(const struct away_tracklist *list,
                                        size_t i) {
  if (list->len > i) {
    return &list->items[i];
  } else {
    return NULL;
  }
}

struct away_track *awayI_tracklist_seti(struct away_tracklist *list, size_t i,
                                        const struct away_track *v) {
  if (list->size > i) {
    struct away_track *arr = list->items;
    arr[i] = *v;
    return &arr[i];
  } else {
    return NULL;
  }
}

struct away_track *awayI_tracklist_push(lua_State *S,
                                        struct away_tracklist *list,
                                        const struct away_track *v) {
  if (awayI_tracklist_ensure_capacity(S, list, 1) == LUA_OK) {
    struct away_track *slot = awayI_tracklist_seti(list, list->len, v);
    if (slot != NULL) {
      list->len++;
    }
    return slot;
  } else {
    return NULL;
  }
}

void awayI_tracklist_swaprmi(struct away_tracklist *list, size_t i) {
  if (list->len > i) {
    struct away_track *arr = list->items;
    struct away_track *tail = &arr[list->len - 1];
    arr[i] = *tail;
    list->len--;
  }
}

void awayI_tracklist_deinit(lua_State *S, struct away_tracklist *list) {
  struct away_tracklist cp = *list;
  *list = awayI_tracklist_empty();
  awayI_free(S, cp.items, sizeof(struct away_track) * cp.size);
}

const char *AWAY_SCHED_TAG = "away.sched";

int awayL_sched_gc(lua_State *S) {
  struct away_sched *sched = luaL_checkudata(S, 1, AWAY_SCHED_TAG);
  luaL_unref(S, LUA_REGISTRYINDEX, sched->lregref);
  awayI_tracklist_deinit(S, &sched->tracks);
  return 0;
}

int awayI_sched_pollf_placeholder(lua_State *S, struct away_sched *sched,
                                  const struct away_poll_deadline *deadline,
                                  void *ud) {
  return 0;
}

/**
 * @brief [0, +1, -] Create a new scheduler. Push the scheduler onto stack.
 * @param S
 * @param nthread
 * @return struct away_sched *
 */
LUA_API struct away_sched *away_sched_new(lua_State *S, int nreg,
                                          away_Time timef, void *timef_ud) {
  luaL_checkstack(S, 3, NULL);
  struct away_sched *sched = lua_newuserdatauv(S, sizeof(struct away_sched), 0);
  luaL_setmetatable(S, AWAY_SCHED_TAG);
  lua_createtable(S, nreg, 0);
  int regref = luaL_ref(S, LUA_REGISTRYINDEX);
  *sched = (struct away_sched){
      .tracks = awayI_tracklist_empty(),
      .active = false,
      .pollf = &awayI_sched_pollf_placeholder,
      .poll_ud = NULL,
      .timef = timef,
      .time_ud = timef_ud,
      .current_time = {0, 0},
      .lregref = regref,
      .lcxrootref = 0,
  };
  int awayI_sched_ref(lua_State *S, struct away_sched *sched);
  lua_newtable(S);
  int cxrootref = awayI_sched_ref(S, sched);
  sched->lcxrootref = cxrootref;
  return sched;
}

void awayI_default_ticker(lua_State *S, struct away_sched *sched, void *ud) {
  if (timespec_get(&sched->current_time, TIME_UTC) == 0) {
    luaL_error(S, "failed to fetch current time");
  }
}

int laway_sched_new(lua_State *S) {
  away_sched_new(S, 0, &awayI_default_ticker, NULL);
  return 1;
}

/**
 * @brief [-0, +1, -] Push the registry onto stack.
 *
 * @param S
 * @param sched_idx
 * @param ref
 */
void awayI_sched_pushreg(lua_State *S, struct away_sched *sched) {
  if (lua_geti(S, LUA_REGISTRYINDEX, sched->lregref) != LUA_TTABLE) {
    luaL_error(S, "internal: uservalue #1 is not table ");
  }
}

/**
 * @brief [-1, 0, -] luaL_ref() but for scheduler.
 *
 * @param S
 * @param sched_idx
 * @return int
 */
int awayI_sched_ref(lua_State *S, struct away_sched *sched) {
  awayI_sched_pushreg(S, sched);
  lua_pushvalue(S, -2);
  int ref = luaL_ref(S, -2);
  lua_pop(S, 2);
  return ref;
}

/**
 * @brief [0, 0, -] luaL_unref() but for scheduler
 *
 * @param S
 * @param sched_idx
 * @param ref
 */
void awayI_sched_unref(lua_State *S, struct away_sched *sched, int ref) {
  awayI_sched_pushreg(S, sched);
  luaL_unref(S, -1, ref);
  lua_pop(S, 1);
}

/**
 * @brief [-0, +0, -] Create and track a new Lua thread. Return NULL if failed.
 *
 * @param S
 * @param sched_idx
 * @return lua_State *
 */
LUA_API lua_State *away_spawn_thread(lua_State *S, struct away_sched *sched) {

  lua_State *th = lua_newthread(S);
  int ref = awayI_sched_ref(S, sched);
  struct away_track *slot =
      awayI_tracklist_push(S, &sched->tracks,
                           &(struct away_track){
                               .S = th,
                               .lref = ref,
                               .sched = sched,
                               .wake_after = ((struct timespec){
                                   .tv_sec = 0,
                                   .tv_nsec = 0,
                               }),
                               .switchto = NULL,
                               .lcxref = 0,
                           });
  if (slot != NULL) {
    struct away_track **store = awayI_get_track_store(th);
    *store = slot;
    return th;
  } else {
    awayI_sched_unref(S, sched, ref);
    return NULL;
  }
}

const struct timespec *awayI_sched_update_time(lua_State *S,
                                               struct away_sched *sched) {
  if (sched->timef == NULL) {
    luaL_error(S, "time function is not specified");
  }
  sched->timef(S, sched, sched->time_ud);
  return &sched->current_time;
}

void awayI_sched_untracki(lua_State *S, struct away_sched *sched, size_t i) {
  if (sched->tracks.len > i) {
    struct away_track *track = &sched->tracks.items[i];
    if (track->lcxref != 0) {
      awayI_sched_unref(S, sched, track->lcxref);
    }
    awayI_sched_unref(S, sched, track->lref);
    awayI_tracklist_swaprmi(&sched->tracks, i);
  }
}

void awayI_sched_untrack(lua_State *S, struct away_sched *sched,
                         struct away_track *track) {
  if (sched->tracks.len > 0) {
    struct away_track *arr = sched->tracks.items;
    if (&arr[0] >= track && &arr[(sched->tracks.len) - 1] <= track) {
      ptrdiff_t idx = track - &arr[0] - 1;
      awayI_sched_untracki(S, sched, idx);
    }
  }
}

struct timespec awayI_timespec_from_int_ms(lua_Integer msec) {
  time_t sec = (msec / 1000);
  long nsec = (msec % 1000) * 1000;
  return (struct timespec){
      .tv_nsec = nsec,
      .tv_sec = sec,
  };
}

struct timespec awayI_timespec_add(const struct timespec *t1,
                                   const struct timespec *t2) {
  long nsec = t1->tv_nsec + t2->tv_nsec;
  time_t sec = t1->tv_sec + t2->tv_sec;
  while (nsec >= 10e9) {
    nsec -= 10e9;
    sec += 1;
  }
  return (struct timespec){
      .tv_nsec = nsec,
      .tv_sec = sec,
  };
}

enum away_thread_status awayI_costatus(lua_State *th) {
  int status = lua_status(th);
  switch (status) {
  case LUA_YIELD:
    return AWAY_TH_YIELD;
  case LUA_OK: {
    lua_Debug ar;
    if (lua_getstack(th, 0, &ar)) {
      return AWAY_TH_NORMAL;
    } else if (lua_gettop(th) == 0) {
      return AWAY_TH_DEAD;
    } else {
      return AWAY_TH_YIELD;
    }
  }
  default:
    return AWAY_TH_DEAD;
  }
}

int awayI_sched_resume(lua_State *S, struct away_sched *sched,
                       struct away_track *track) {
  lua_State *th = track->S;
  enum away_thread_status status = awayI_costatus(th);
  if (status == AWAY_TH_YIELD || status == AWAY_TH_NORMAL) {
    int nres = 0;
    int ret = lua_resume(th, S, 0, &nres);
    if (ret == LUA_YIELD || ret == LUA_OK) {
      lua_pop(th, nres);
    } else {
      const char *s = lua_tostring(th, -1);
      luaL_traceback(S, th, s, 0);
      lua_error(S);
    }
    return ret;
  } else {
    luaL_traceback(S, th, "thread exited with unknown error", 0);
    lua_error(S);
  }
}

struct timespec awayI_timespec_duration(const struct timespec *from,
                                        const struct timespec *to) {
  time_t sec = to->tv_sec - from->tv_sec;
  long nsec = from->tv_nsec - to->tv_nsec;
  if (nsec < 0) {
    sec = sec - 1;
    nsec = 10e9 + nsec;
  }
  if (sec < 0) {
    sec = 0;
    nsec = 0;
  }
  return (struct timespec){
      .tv_nsec = nsec,
      .tv_sec = sec,
  };
}

/* t1 > t0 */
bool awayI_timespec_is_before(const struct timespec *t0,
                              const struct timespec *t1) {
  return t1->tv_sec > t0->tv_sec ||
         (t1->tv_sec == t0->tv_sec && t1->tv_nsec > t0->tv_nsec);
}

/* t1 < t0 */
bool awayI_timespec_is_after(const struct timespec *t0,
                             const struct timespec *t1) {
  return t1->tv_sec < t0->tv_sec ||
         (t1->tv_sec == t0->tv_sec && t1->tv_nsec < t0->tv_nsec);
}

LUA_API void away_sched_run(lua_State *S, struct away_sched *sched) {
  sched->active = true;
  void *time_ud = NULL;
  away_Time timef = away_sched_gettimef(sched, &time_ud);
  void *poll_ud = NULL;
  away_Poll pollf = away_sched_getpollf(sched, &poll_ud);
  if (timef == NULL) {
    luaL_error(S, "no time function");
  } else if (pollf == NULL) {
    luaL_error(S, "no poll function");
  }
  while (sched->active) {
    timef(S, sched, time_ud);
    const struct timespec *current_time = &sched->current_time;
    struct timespec next_deadline = *current_time;
    struct timespec *next_deadline_ptr = NULL;
    struct away_track *arr = sched->tracks.items;
    for (size_t i = 0; i < sched->tracks.len; i++) {
      struct away_track *track = &arr[i];
      if (awayI_timespec_is_after(current_time, &track->wake_after)) {
        int ret = awayI_sched_resume(S, sched, track);

        struct away_track *switchto = track->switchto;
        track->switchto = NULL;
        while (switchto != NULL) {
          int ret1 = awayI_sched_resume(S, sched, switchto);
          if (ret1 == LUA_OK) {
            awayI_sched_untrack(S, sched, switchto);
          }
          switchto = switchto->switchto;
        }

        if (ret == LUA_OK) {
          awayI_sched_untracki(S, sched, i);
        }
      }
      if (next_deadline_ptr == NULL ||
          awayI_timespec_is_before(next_deadline_ptr, &track->wake_after)) {
        next_deadline = track->wake_after;
        next_deadline_ptr = &next_deadline;
      }
    }
    struct timespec duration =
        awayI_timespec_duration(current_time, &next_deadline);
    struct away_poll_deadline pdl = {
        .start = current_time,
        .deadline = &next_deadline,
        .left = &duration,
    };
    pollf(S, sched, &pdl, poll_ud);
  }
}

void away_sched_stop(struct away_sched *sched) { sched->active = false; }

void away_set_timer(struct away_track *track, const struct timespec *timeout) {
  track->wake_after = awayI_timespec_add(&track->sched->current_time, timeout);
}

struct away_track *away_get_track(lua_State *th) {
  struct away_track *track = *awayI_get_track_store(th);
  if (track->S != th) {
    return NULL;
  }
  return track;
}

void away_sched_setpollf(struct away_sched *sched, away_Poll pollf, void *ud) {
  sched->pollf = pollf;
  sched->poll_ud = ud;
}

away_Poll away_sched_getpollf(struct away_sched *sched, void **ud) {
  *ud = sched->poll_ud;
  return sched->pollf;
}

void away_sched_settimef(struct away_sched *sched, away_Time timef, void *ud) {
  sched->timef = timef;
  sched->time_ud = ud;
}

away_Time away_sched_gettimef(struct away_sched *sched, void **ud) {
  *ud = sched->time_ud;
  return sched->timef;
}

int awayI_yield_section1(lua_State *S, int status, lua_KContext cx) {
  return 0;
}

void away_yield(lua_State *th) { lua_yieldk(th, 0, 0, &awayI_yield_section1); }

void away_switchto(struct away_track *original, struct away_track *switchto) {
  original->switchto = switchto;
}

#define VarMaxValue(v)                                                         \
  _Generic(v, char                                                             \
           : CHAR_MAX, unsigned char                                           \
           : UCHAR_MAX, signed char                                            \
           : SCHAR_MAX, signed short                                           \
           : SHRT_MAX, unsigned short                                          \
           : USHRT_MAX, signed int                                             \
           : INT_MAX, unsigned int                                             \
           : UINT_MAX, signed long                                             \
           : LONG_MAX, unsigned long                                           \
           : ULONG_MAX, signed long long                                       \
           : LLONG_MAX, unsigned long long                                     \
           : ULLONG_MAX, float                                                 \
           : FLT_MAX, double                                                   \
           : DBL_MAX, long double                                              \
           : LDBL_MAX )

void away_pause(struct away_track *track) {
  track->wake_after = (struct timespec){
      .tv_nsec = LONG_MAX,
      .tv_sec = VarMaxValue((time_t)0),
  };
}

void away_copycx(struct away_track *src, struct away_track *dst) {
  lua_newtable(dst->S);
  int newcx_idx = lua_gettop(dst->S);
  if (src != NULL && src->lcxref != 0) {
    awayI_sched_pushreg(src->S, src->sched);
    lua_rawgeti(src->S, -1, src->lcxref);
    lua_xmove(src->S, dst->S, 1);
    lua_pop(src->S, 1);
  } else {
    awayI_sched_pushreg(dst->S, dst->sched);
    lua_rawgeti(dst->S, -1, dst->sched->lcxrootref);
    lua_insert(dst->S, -2);
    lua_pop(dst->S, 1);
  }
  lua_createtable(dst->S, 0, 1);
  lua_insert(dst->S, -2);
  lua_setfield(dst->S, -2, "__index");
  lua_setmetatable(dst->S, newcx_idx);
  lua_pushvalue(dst->S, newcx_idx);
  dst->lcxref = awayI_sched_ref(dst->S, dst->sched);
}

void away_context(struct away_track *track) {
  if (track->lcxref != 0) {
    awayI_sched_pushreg(track->S, track->sched);
    lua_rawgeti(track->S, -1, track->lcxref);
    lua_insert(track->S, -2);
    lua_pop(track->S, 1);
  } else {
    lua_pushnil(track->S);
  }
}

int laway_set_timer(lua_State *S) {
  lua_Integer msec = luaL_checkinteger(S, 1);
  struct timespec timeout = awayI_timespec_from_int_ms(msec);
  struct away_track *track = away_get_track(S);
  if (track == NULL) {
    luaL_error(S, "caller thread is not tracked by scheduler");
  }
  away_set_timer(track, &timeout);
  return 0;
}

int laway_spawn_thread(lua_State *S) {
  struct away_sched *sched = lua_isnil(S, 1) ? NULL : luaL_checkudata(S, 1, AWAY_SCHED_TAG);
  struct away_track *cx_src = NULL;
  luaL_checktype(S, 2, LUA_TFUNCTION);
  if (sched == NULL) {
    struct away_track *track = away_get_track(S);
    if (track != NULL) {
      sched = track->sched;
      cx_src = track;
    } else {
      luaL_error(S, "caller thread is not tracked by scheduler");
    }
  }
  lua_State *th = away_spawn_thread(S, sched);
  if (th != NULL) {
    lua_pushvalue(S, 2);
    lua_xmove(S, th, 1);
    lua_pushthread(th);
    lua_xmove(th, S, 1);
  } else {
    lua_pushnil(S);
  }
  away_copycx(cx_src, away_get_track(th));
  lua_pop(th, 1);
  return 1;
}

int laway_run(lua_State *S) {
  struct away_sched *sched = luaL_checkudata(S, 1, AWAY_SCHED_TAG);
  away_sched_run(S, sched);
  return 0;
}

int laway_sched_stop(lua_State *S) {
  struct away_sched *sched = luaL_checkudata(S, 1, AWAY_SCHED_TAG);
  away_sched_stop(sched);
  return 0;
}

int laway_yield(lua_State *S) {
  away_yield(S);
  return 0;
}

void *awayI_checkludata(lua_State *S, int n) {
  if (lua_islightuserdata(S, n)) {
    return lua_touserdata(S, n);
  } else {
    luaL_error(S, "arg #%d is %s, expect (light)userdata", n,
               luaL_typename(S, n));
  }
}

int laway_setpollf(lua_State *S) {
  struct away_sched *sched = luaL_checkudata(S, 1, AWAY_SCHED_TAG);
  if (lua_islightuserdata(S, 2)) {
    void *ud = luaL_opt(S, awayI_checkludata, 3, NULL);
    away_sched_setpollf(sched, lua_touserdata(S, 2), ud);
    return 0;
  } else {
    luaL_typeerror(S, 2, "(light)userdata");
  }
}

int laway_settimef(lua_State *S) {
  struct away_sched *sched = luaL_checkudata(S, 1, AWAY_SCHED_TAG);
  if (lua_islightuserdata(S, 2)) {
    void *ud = luaL_opt(S, awayI_checkludata, 3, NULL);
    away_sched_settimef(sched, lua_touserdata(S, 2), ud);
    return 0;
  } else {
    luaL_typeerror(S, 2, "(light)userdata");
  }
}

int laway_hrt_now(lua_State *S) {
  struct timespec now = {};
  if (timespec_get(&now, TIME_UTC) == TIME_UTC) {
    lua_pushnumber(S, now.tv_sec);
    lua_pushinteger(S, now.tv_nsec);
    return 2;
  } else {
    luaL_error(S, "failed to call timespec_get()");
  }
}

int laway_switchto(lua_State *S) {
  lua_State *th = NULL;
  if (!lua_isnoneornil(S, 1)) {
    luaL_checktype(S, 1, LUA_TTHREAD);
    th = lua_tothread(S, 1);
  }
  struct away_track *original = away_get_track(S);
  struct away_track *switchto = away_get_track(th);
  if (original == NULL) {
    luaL_error(S, "caller thread is not tracked by scheduler");
  } else if (th != NULL && switchto == NULL) {
    luaL_error(S, "target thread is not tracked by scheduler");
  }
  away_switchto(original, switchto);
  return 0;
}

int laway_pause(lua_State *S) {
  struct away_track *track = away_get_track(S);
  if (track != NULL) {
    away_pause(track);
  } else {
    luaL_error(S, "caller thread is not tracked by scheduler");
  }
  return 0;
}

int laway_current(lua_State *S) {
  struct away_track *track = away_get_track(S);
  if (track != NULL) {
    lua_pushthread(S);
  } else {
    luaL_error(S, "caller thread is not tracked by scheduler");
  }
  return 1;
}

int laway_context(lua_State *S) {
  struct away_track *track = away_get_track(S);
  if (track != NULL) {
    away_context(track);
    return 1;
  } else {
    luaL_error(S, "caller thread is not tracked by scheduler");
  }
}

int laway_rootcontext(lua_State *S) {
  struct away_sched *sched = luaL_checkudata(S, 1, AWAY_SCHED_TAG);
  awayI_sched_pushreg(S, sched);
  lua_rawgeti(S, -1, sched->lcxrootref);
  lua_insert(S, -2);
  lua_pop(S, 1);
  return 1;
}

const luaL_Reg AWAY_SCHED_METATAB[] = {
    {"__gc", awayL_sched_gc},
    {NULL, NULL},
};

const luaL_Reg AWAY[] = {{"sched", &laway_sched_new},
                         {"spawn", &laway_spawn_thread},
                         {"set_timer", &laway_set_timer},
                         {"run", &laway_run},
                         {"stop", &laway_sched_stop},
                         {"yield", &laway_yield},
                         {"setpollf", &laway_setpollf},
                         {"settimef", &laway_settimef},
                         {"hrt_now", &laway_hrt_now},
                         {"switchto", &laway_switchto},
                         {"pause", &laway_pause},
                         {"current", &laway_current},
                         {"context", &laway_context},
                         {"root_context", &laway_rootcontext},
                         {NULL, NULL}};

LUA_API int luaopen_away(lua_State *S) {
  luaL_newlibtable(S, AWAY_SCHED_METATAB);
  luaL_newmetatable(S, AWAY_SCHED_TAG);
  luaL_newlib(S, AWAY);
  return 1;
}
