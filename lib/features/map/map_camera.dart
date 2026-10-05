/// 地図を開いて現在地がわかったときの倍率。「このあたりを探す」の半径1kmが、スマホの幅におさまる。
const neighborhoodZoom = 14.0;

/// 地図を開いたあとに現在地がわかったとき、そこへ寄せるか。
/// わかる前に自分で地図を動かしたときや、旅路を見ているときは動かさない。
bool shouldCenterOnArrivedLocation({
  required bool userMoved,
  required bool showingJourney,
}) => !userMoved && !showingJourney;
