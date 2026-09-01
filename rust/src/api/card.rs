use flutter_rust_bridge::frb;
use njupt::{Credentials, FetchMode, login_card, login_card_via_webvpn, Card};
use serde::Serialize;

use super::jwxt::BridgeFetchMode;

fn mode_of(mode: BridgeFetchMode) -> FetchMode {
    match mode {
        BridgeFetchMode::CacheFirst => FetchMode::CacheFirst,
        BridgeFetchMode::NetworkOnly => FetchMode::NetworkOnly,
    }
}

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

#[frb(opaque)]
pub struct CardHandle {
    inner: Card,
}

#[frb]
pub async fn login_card_campus(
    username: String,
    password: String,
) -> Result<CardHandle, String> {
    let creds = Credentials::new(username, password);
    login_card(&creds)
        .await
        .map(|inner| CardHandle { inner })
        .map_err(|e| e.to_string())
}

#[frb]
pub async fn login_card_off_campus(
    username: String,
    password: String,
) -> Result<CardHandle, String> {
    let creds = Credentials::new(username, password);
    login_card_via_webvpn(&creds)
        .await
        .map(|inner| CardHandle { inner })
        .map_err(|e| e.to_string())
}

#[frb]
pub async fn fetch_card_balance(
    card: &CardHandle,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = card
        .inner
        .balance(mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub async fn fetch_card_balance_json(
    card: &CardHandle,
    mode: BridgeFetchMode,
) -> Result<String, String> {
    let v = card
        .inner
        .balance_json(mode_of(mode))
        .await
        .map_err(|e| e.to_string())?;
    cached_json(v)
}

#[frb]
pub fn clear_card_cache(card: &CardHandle) {
    card.inner.clear_cache();
}
