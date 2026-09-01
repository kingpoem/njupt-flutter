use flutter_rust_bridge::frb;
use njupt::{
    CacheKey, CacheKind, Credentials, FetchMode, Jwxt, Term, login_jwxt, login_jwxt_via_webvpn,
};
use serde::Serialize;
use serde_json::Value;

fn cached_json<T: Serialize>(cached: njupt::Cached<T>) -> Result<String, String> {
    #[derive(Serialize)]
    struct Out<T> {
        data: T,
        from_cache: bool,
    }
    serde_json::to_string(&Out {
        data: cached.data,
        from_cache: cached.from_cache,
    })
    .map_err(|e| e.to_string())
}

fn cached_value(cached: njupt::Cached<Value>) -> Result<String, String> {
    cached_json(cached)
}

fn term_of(term: BridgeTerm) -> Term {
    match term {
        BridgeTerm::First => Term::First,
        BridgeTerm::Second => Term::Second,
    }
}

fn mode_of(mode: BridgeFetchMode) -> FetchMode {
    match mode {
        BridgeFetchMode::CacheFirst => FetchMode::CacheFirst,
        BridgeFetchMode::NetworkOnly => FetchMode::NetworkOnly,
    }
}

fn kind_of(kind: BridgeCacheKind) -> CacheKind {
    match kind {
        BridgeCacheKind::Grades => CacheKind::Grades,
        BridgeCacheKind::GradeDetails => CacheKind::GradeDetails,
        BridgeCacheKind::Schedule => CacheKind::Schedule,
        BridgeCacheKind::Exams => CacheKind::Exams,
        BridgeCacheKind::MakeupExams => CacheKind::MakeupExams,
        BridgeCacheKind::DeferredExams => CacheKind::DeferredExams,
        BridgeCacheKind::Selected => CacheKind::Selected,
        BridgeCacheKind::Profile => CacheKind::Profile,
    }
}

#[derive(Clone, Copy)]
pub enum BridgeTerm {
    First,
    Second,
}

#[derive(Clone, Copy)]
pub enum BridgeFetchMode {
    CacheFirst,
    NetworkOnly,
}

#[derive(Clone, Copy)]
pub enum BridgeCacheKind {
    Grades,
    GradeDetails,
    Schedule,
    Exams,
    MakeupExams,
    DeferredExams,
    Selected,
    Profile,
}

#[frb(opaque)]
pub struct JwxtHandle {
    inner: Jwxt,
}

#[frb]
pub async fn login_campus(username: String, password: String) -> Result<JwxtHandle, String> {
    let creds = Credentials::new(username, password);
    login_jwxt(&creds)
        .await
        .map(|inner| JwxtHandle { inner })
        .map_err(|e| e.to_string())
}

#[frb]
pub async fn login_off_campus(username: String, password: String) -> Result<JwxtHandle, String> {
    let creds = Credentials::new(username, password);
    login_jwxt_via_webvpn(&creds)
        .await
        .map(|inner| JwxtHandle { inner })
        .map_err(|e| e.to_string())
}

#[frb]
pub async fn ensure_session(jwxt: &JwxtHandle) -> Result<(), String> {
    jwxt.inner.ensure_session().await.map_err(|e| e.to_string())
}

#[frb]
pub async fn fetch_schedule(
    jwxt: &JwxtHandle,
    year: u32,
    term: BridgeTerm,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .student_schedule(year, term_of(term), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_schedule_json(
    jwxt: &JwxtHandle,
    year: u32,
    term: BridgeTerm,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .student_schedule_json(year, term_of(term), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_value(v)
}

#[frb]
pub async fn fetch_grades(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .student_grades(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_grades_json(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .student_grades_json(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_value(v)
}

#[frb]
pub async fn fetch_grade_details(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .grade_details(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_grade_details_json(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .grade_details_json(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_value(v)
}

#[frb]
pub async fn fetch_exams(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .student_exams(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_exams_json(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .student_exams_json(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_value(v)
}

#[frb]
pub async fn fetch_makeup_exams(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .makeup_exams(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_makeup_exams_json(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .makeup_exams_json(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_value(v)
}

#[frb]
pub async fn fetch_deferred_exams(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .deferred_exams(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_deferred_exams_json(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .deferred_exams_json(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_value(v)
}

#[frb]
pub async fn fetch_selected(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .selected_courses(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_selected_json(
    jwxt: &JwxtHandle,
    year: Option<u32>,
    term: Option<BridgeTerm>,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .selected_courses_json(year, term.map(term_of), mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_value(v)
}

#[frb]
pub async fn fetch_profile(jwxt: &JwxtHandle, mode: BridgeFetchMode) -> Result<String, String> {
    let v = jwxt
        .inner
        .student_profile(mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_profile_fields(
    jwxt: &JwxtHandle,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .student_profile(mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    #[derive(Serialize)]
    struct Out {
        data: Value,
        from_cache: bool,
    }
    serde_json::to_string(&Out {
        data: v.data.as_json(),
        from_cache: v.from_cache,
    })
    .map_err(|e| e.to_string())
}

#[frb(opaque)]
pub struct SelectionContextHandle {
    inner: njupt::SelectionContext,
}

#[frb]
pub async fn fetch_selection_context(
    jwxt: &JwxtHandle,
) -> Result<SelectionContextHandle, String> {
    jwxt
        .inner
        .selection_context()
        .await
        .map(|inner| SelectionContextHandle { inner })
        .map_err(|e| e.to_string())
}

#[frb]
pub fn selection_context_json(ctx: &SelectionContextHandle) -> Result<String, String> {
    serde_json::to_string(&ctx.inner).map_err(|e| e.to_string())
}

#[derive(Clone)]
pub struct BridgeSelectableSearch {
    pub year: u32,
    pub term: BridgeTerm,
    pub kklxdm: String,
    pub filter: Option<String>,
    pub page_start: u32,
    pub page_end: u32,
    pub only_available: bool,
}

#[derive(Clone)]
pub struct BridgeClassDetailQuery {
    pub year: u32,
    pub term: BridgeTerm,
    pub kklxdm: String,
    pub kch_id: String,
    pub xkkz_id: String,
}

#[frb]
pub async fn search_selectable_courses(
    jwxt: &JwxtHandle,
    ctx: &SelectionContextHandle,
    query: BridgeSelectableSearch,
) -> Result<String, String> {
    let q = njupt::SelectableSearch {
        year: query.year,
        term: term_of(query.term),
        kklxdm: query.kklxdm,
        filter: query.filter,
        page_start: query.page_start,
        page_end: query.page_end,
        only_available: query.only_available,
    };
    let v = jwxt
        .inner
        .search_selectable_courses(&ctx.inner, &q)
        .await
        .map_err(|e| e.to_string())?;
    serde_json::to_string(&v).map_err(|e| e.to_string())
}

#[frb]
pub async fn selectable_class_details(
    jwxt: &JwxtHandle,
    ctx: &SelectionContextHandle,
    query: BridgeClassDetailQuery,
) -> Result<String, String> {
    let q = njupt::ClassDetailQuery {
        year: query.year,
        term: term_of(query.term),
        kklxdm: query.kklxdm,
        kch_id: query.kch_id,
        xkkz_id: query.xkkz_id,
    };
    let v = jwxt
        .inner
        .selectable_class_details(&ctx.inner, &q)
        .await
        .map_err(|e| e.to_string())?;
    serde_json::to_string(&v).map_err(|e| e.to_string())
}

#[frb]
pub async fn selection_chosen(
    jwxt: &JwxtHandle,
    ctx: &SelectionContextHandle,
    year: u32,
    term: BridgeTerm,
) -> Result<String, String> {
    let v = jwxt
        .inner
        .selection_chosen(&ctx.inner, year, term_of(term))
        .await
        .map_err(|e| e.to_string())?;
    serde_json::to_string(&v).map_err(|e| e.to_string())
}

#[frb]
pub fn has_cache(
    jwxt: &JwxtHandle,
    kind: BridgeCacheKind,
    year: Option<u32>,
    term: Option<BridgeTerm>,
) -> bool {
    jwxt
        .inner
        .has_cache(&CacheKey::new(kind_of(kind), year, term.map(term_of)))
}

#[frb]
pub fn invalidate_cache(
    jwxt: &JwxtHandle,
    kind: BridgeCacheKind,
    year: Option<u32>,
    term: Option<BridgeTerm>,
) -> bool {
    jwxt
        .inner
        .invalidate_cache(&CacheKey::new(kind_of(kind), year, term.map(term_of)))
}

#[frb]
pub fn invalidate_cache_kind(jwxt: &JwxtHandle, kind: BridgeCacheKind) {
    jwxt.inner.invalidate_cache_kind(kind_of(kind));
}

#[frb]
pub fn clear_jwxt_cache(jwxt: &JwxtHandle) {
    jwxt.inner.clear_cache();
}

#[frb]
pub fn jwxt_cache_len(jwxt: &JwxtHandle) -> usize {
    jwxt.inner.cache_len()
}
