#include <lua.h>
#include <stdbool.h>
#include <time.h>

struct away_poll_deadline {
  const struct timespec *start;
  const struct timespec *deadline;
  const struct timespec *left;
};

struct away_track {
  lua_State *S;
  struct away_sched *sched;
  struct timespec wake_after;
  struct away_track *switchto;
  int lref;
};

struct away_tracklist {
  struct away_track *items;
  size_t size;
  size_t len;
};

typedef int (*away_Poll)(lua_State *S, struct away_sched *sched,
                         const struct away_poll_deadline *deadline, void *ud);

typedef void (*away_Time)(lua_State *S, struct away_sched *sched, void *ud);

struct away_sched {
  bool active;
  struct away_tracklist tracks;
  away_Poll pollf;
  void *poll_ud;
  away_Time timef;
  void *time_ud;
  struct timespec current_time;
  lua_Integer lregref;
};

LUA_API struct away_sched *away_sched_new(lua_State *S, int nreg,
                                          away_Time timef, void *time_ud);

LUA_API lua_State *away_spawn_thread(lua_State *S, struct away_sched *sched);

LUA_API void away_sched_run(lua_State *S, struct away_sched *sched);

void away_sched_setpollf(struct away_sched *sched, away_Poll pollf, void *ud);

away_Poll away_sched_getpollf(struct away_sched *sched, void **ud);

void away_sched_settimef(struct away_sched *sched, away_Time timef, void *ud);

away_Time away_sched_gettimef(struct away_sched *sched, void **ud);

struct away_track *away_get_track(lua_State *th);

/* away calls */

void away_set_timer(struct away_track *track, const struct timespec *timeout);

void away_yield(lua_State *S);

void away_switchto(struct away_track *track, struct away_track *target);

void away_pause(struct away_track *track);

LUA_API int luaopen_away(lua_State *S);
