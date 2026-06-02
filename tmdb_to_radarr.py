#!/usr/bin/env python3
"""
tmdb_to_radarr.py
-----------------
Fetches upcoming movies from TMDB with a rating >= MIN_RATING
and adds any new ones to Radarr automatically.

Requirements:
    pip install requests radarr

Environment variables (or edit the CONFIG block below):
    TMDB_API_KEY   – TMDB v3 API key  (https://www.themoviedb.org/settings/api)
    RADARR_URL     – Base URL of your Radarr instance  (e.g. http://localhost:7878)
    RADARR_API_KEY – Radarr API key  (Settings → General → Security)
"""

import os
import sys
import logging
from datetime import date, timedelta
import requests
import radarr
from radarr.rest import ApiException

# ---------------------------------------------------------------------------
# CONFIG – override via environment variables or edit directly
# ---------------------------------------------------------------------------
TMDB_API_KEY   = os.getenv("TMDB_API_KEY",   "YOUR_TMDB_API_KEY")
RADARR_URL     = os.getenv("RADARR_URL",     "http://localhost:7878")
RADARR_API_KEY = os.getenv("RADARR_API_KEY", "YOUR_RADARR_API_KEY")

MIN_RATING       = 9   # Minimum TMDB vote average
MIN_VOTE_COUNT   = 50    # Ignore movies with too few votes (unreliable rating)
MAX_PAGES        = 5     # TMDB pages to fetch (20 movies per page)
QUALITY_PROFILE  = "HD-1080p"   # Radarr quality profile name (must exist)
ROOT_FOLDER      = "/mnt/movies/movies"    # Radarr root folder path (must exist)
MONITOR          = True         # Monitor new movies in Radarr
SEARCH_ON_ADD    = False         # Trigger a search in Radarr immediately on add
RELEASE_WINDOW_DAYS = 180       # How many days ahead to look for upcoming releases
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

TMDB_BASE = "https://api.themoviedb.org/3"


# ---------------------------------------------------------------------------
# TMDB helpers
# ---------------------------------------------------------------------------

def fetch_upcoming_movies(pages: int = MAX_PAGES) -> list[dict]:
    """Discover upcoming movies from TMDB using the /discover/movie endpoint.

    Filters are applied server-side:
      - primary_release_date between today and RELEASE_WINDOW_DAYS ahead
      - theatrical release types only (limited + wide)
      - vote_average >= MIN_RATING and vote_count >= MIN_VOTE_COUNT
    Results are sorted by primary_release_date ascending.
    """
    today     = date.today()
    date_from = (today - timedelta(days=90)).isoformat()
    date_to   = (today + timedelta(days=RELEASE_WINDOW_DAYS)).isoformat()

    movies: list[dict] = []
    for page in range(1, pages + 1):
        url = f"{TMDB_BASE}/discover/movie"
        params = {
            "api_key":                  TMDB_API_KEY,
            "language":                 "en-US",
            "region":                   "US",
            "sort_by":                  "primary_release_date.asc",
            "include_adult":            "false",
            "include_video":            "false",
            "primary_release_date.gte": date_from,
            "primary_release_date.lte": date_to,
            "with_release_type":        "2|3",
            "vote_average.gte":         MIN_RATING,
            "vote_count.gte":           MIN_VOTE_COUNT,
            "page":                     page,
        }
        try:
            resp = requests.get(url, params=params, timeout=15)
            resp.raise_for_status()
        except requests.RequestException as exc:
            log.error("TMDB request failed (page %d): %s", page, exc)
            break

        data = resp.json()
        results = data.get("results", [])
        movies.extend(results)
        log.info(
            "TMDB page %d/%d – %d movies fetched (release window: %s → %s)",
            page, data.get("total_pages", page), len(results), date_from, date_to,
        )

        if page >= data.get("total_pages", page):
            break

    return movies


def filter_by_rating(movies: list[dict]) -> list[dict]:
    """Keep only movies that meet the minimum rating and vote-count thresholds."""
    filtered = [
        m for m in movies
        if m.get("vote_average", 0) >= MIN_RATING
        and m.get("vote_count",   0) >= MIN_VOTE_COUNT
    ]
    log.info(
        "Rating filter (≥ %.1f, ≥ %d votes): %d → %d movies",
        MIN_RATING, MIN_VOTE_COUNT, len(movies), len(filtered),
    )
    return filtered


# ---------------------------------------------------------------------------
# Radarr helpers
# ---------------------------------------------------------------------------

def build_api_client() -> radarr.ApiClient:
    """Create and return a configured Radarr ApiClient."""
    configuration = radarr.Configuration(host=RADARR_URL)
    configuration.api_key = {"apikey": RADARR_API_KEY}
    return radarr.ApiClient(configuration)


def get_quality_profile_id(api_client: radarr.ApiClient, name: str) -> int:
    """Return the Radarr quality-profile ID that matches *name*."""
    qp_api = radarr.QualityProfileApi(api_client)
    profiles = qp_api.list_quality_profile()
    for profile in profiles:
        if profile.name.lower() == name.lower():
            return profile.id
    available = [p.name for p in profiles]
    raise ValueError(
        f"Quality profile '{name}' not found in Radarr. "
        f"Available profiles: {available}"
    )


def get_existing_tmdb_ids(api_client: radarr.ApiClient) -> set[int]:
    """Return the set of TMDB IDs already present in the Radarr library."""
    movie_api = radarr.MovieApi(api_client)
    library = movie_api.list_movie()
    return {m.tmdb_id for m in library if m.tmdb_id}


def add_movie_to_radarr(
    api_client: radarr.ApiClient,
    tmdb_id: int,
    quality_profile_id: int,
    root_folder: str,
) -> bool:
    """
    Look up a movie by TMDB ID and add it to Radarr.
    Returns True on success, False if skipped / failed.
    """
    lookup_api = radarr.MovieLookupApi(api_client)
    movie_api  = radarr.MovieApi(api_client)

    # --- Lookup ---
    try:
        results = lookup_api.list_movie_lookup(term=f"tmdb:{tmdb_id}")
    except ApiException as exc:
        log.warning("  Lookup failed for TMDB ID %d: %s", tmdb_id, exc)
        return False

    if not results:
        log.warning("  No Radarr lookup result for TMDB ID %d", tmdb_id)
        return False

    movie  = results[0]
    title  = movie.title or "Unknown"
    year   = movie.year  or "?"

    # --- Build MovieResource with add options ---
    movie.quality_profile_id = quality_profile_id
    movie.root_folder_path   = root_folder
    movie.monitored          = MONITOR
    movie.add_options        = radarr.AddMovieOptions(
        search_for_movie=SEARCH_ON_ADD,
    )

    # --- Submit to Radarr ---
    try:
        movie_api.create_movie(movie_resource=movie)
        log.info("  ✔ Added: %s (%s)", title, year)
        return True
    except ApiException as exc:
        if exc.status == 400 and "already" in (exc.body or "").lower():
            log.info("  – Already in Radarr: %s (%s)", title, year)
        else:
            log.error("  ✘ Failed to add %s (%s): [%d] %s", title, year, exc.status, exc.reason)
        return False


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    # Basic config validation
    if "YOUR_" in TMDB_API_KEY or "YOUR_" in RADARR_API_KEY:
        log.error(
            "Please set TMDB_API_KEY and RADARR_API_KEY via environment variables "
            "or edit the CONFIG block at the top of this script."
        )
        sys.exit(1)

    # --- Connect to Radarr and resolve quality profile ---
    log.info("Connecting to Radarr at %s …", RADARR_URL)
    api_client = build_api_client()
    try:
        quality_profile_id = get_quality_profile_id(api_client, QUALITY_PROFILE)
        log.info("Connected – using quality profile: %s (id=%d)", QUALITY_PROFILE, quality_profile_id)
    except ApiException as exc:
        log.error("Cannot connect to Radarr: [%d] %s", exc.status, exc.reason)
        sys.exit(1)
    except ValueError as exc:
        log.error("%s", exc)
        sys.exit(1)

    # --- Load existing library to skip duplicates ---
    log.info("Loading existing Radarr library …")
    existing_ids = get_existing_tmdb_ids(api_client)
    log.info("  %d movies already in Radarr", len(existing_ids))

    # --- Fetch and filter upcoming movies from TMDB ---
    log.info("Fetching upcoming movies from TMDB (up to %d pages) …", MAX_PAGES)
    upcoming   = fetch_upcoming_movies(MAX_PAGES)
    qualifying = filter_by_rating(upcoming)

    # Deduplicate by TMDB ID
    seen: set[int] = set()
    unique_qualifying = []
    for m in qualifying:
        tid = m.get("id")
        if tid and tid not in seen:
            seen.add(tid)
            unique_qualifying.append(m)

    # --- Log every qualifying movie ---
    log.info("%d qualifying movies found:", len(unique_qualifying))
    for m in unique_qualifying:
        log.info(
            "  [QUALIFYING] %s (%s) | Rating: %.1f (%d votes) | TMDB ID: %d",
            m.get("title", "Unknown"),
            m.get("release_date", "????")[:4],
            m.get("vote_average", 0),
            m.get("vote_count", 0),
            m["id"],
        )

    # --- Add new movies to Radarr ---
    new_movies = [m for m in unique_qualifying if m["id"] not in existing_ids]
    skipped    = len(unique_qualifying) - len(new_movies)

    if skipped:
        log.info("%d already in Radarr library:", skipped)
        for m in unique_qualifying:
            if m["id"] in existing_ids:
                log.info(
                    "  [IN LIBRARY] %s (%s) | TMDB ID: %d",
                    m.get("title", "Unknown"),
                    m.get("release_date", "????")[:4],
                    m["id"],
                )

    added = failed = 0
    for movie in new_movies:
        tmdb_id = movie["id"]
        title   = movie.get("title", "Unknown")
        rating  = movie.get("vote_average", 0)
        votes   = movie.get("vote_count", 0)
        log.info(
            "Processing: %s | Rating: %.1f (%d votes) | TMDB ID: %d",
            title, rating, votes, tmdb_id,
        )
        ok = add_movie_to_radarr(api_client, tmdb_id, quality_profile_id, ROOT_FOLDER)
        if ok:
            added += 1
        else:
            failed += 1

    # --- Summary ---
    log.info("─" * 50)
    log.info("Done. Added: %d | Skipped (existing): %d | Failed: %d", added, skipped, failed)


if __name__ == "__main__":
    main()