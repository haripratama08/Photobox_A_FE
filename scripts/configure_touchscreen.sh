#!/usr/bin/env bash
set -u

# LXDE/lightdm kadang tidak mengisi XDG_SESSION_TYPE meskipun DISPLAY X11
# tersedia. Yang dibutuhkan xinput adalah DISPLAY aktif, bukan variabel itu.
if [ -z "${DISPLAY:-}" ]; then
  echo "[TOUCH] DISPLAY X11 tidak tersedia; pemetaan xinput dilewati."
  exit 0
fi

if ! command -v xinput >/dev/null 2>&1 || ! command -v xrandr >/dev/null 2>&1; then
  echo "[TOUCH] xinput/xrandr belum tersedia. Instal paket 'xinput' dan 'x11-xserver-utils'."
  exit 0
fi

touch_output="${TOUCH_OUTPUT:-}"
if [ -z "$touch_output" ]; then
  touch_output="$(xrandr --query | awk '/ connected primary/{print $1; exit}')"
fi
if [ -z "$touch_output" ]; then
  touch_output="$(xrandr --query | awk '/ connected/{print $1; exit}')"
fi

if [ -z "$touch_output" ]; then
  echo "[TOUCH] Output display aktif tidak ditemukan."
  exit 0
fi

touch_ids=""
if [ -n "${TOUCH_DEVICE:-}" ]; then
  # Satu panel touchscreen sering muncul sebagai dua device XInput dengan
  # nama identik. `xinput list --id-only <nama>` gagal bila namanya ambigu,
  # jadi ambil seluruh ID yang namanya cocok dari daftar perangkat.
  if [[ "$TOUCH_DEVICE" =~ ^[0-9]+$ ]]; then
    touch_ids="$TOUCH_DEVICE"
  else
    touch_ids="$(xinput list --short \
      | grep -iF -- "$TOUCH_DEVICE" \
      | sed -n 's/.*id=\([0-9][0-9]*\).*/\1/p' || true)"
  fi
else
  touch_ids="$(xinput list --short \
    | grep -Ei 'touch|multitouch|egalax|goodix|ilitek|quanta|silead|wave|wch' \
    | sed -n 's/.*id=\([0-9][0-9]*\).*/\1/p' || true)"
fi

if [ -z "$touch_ids" ]; then
  echo "[TOUCH] Perangkat touchscreen belum terdeteksi."
  xinput list --short
  exit 0
fi

echo "[TOUCH] Output=$touch_output; ID terdeteksi: $(echo "$touch_ids" | tr '\n' ' ')"

configured=0
while IFS= read -r touch_id; do
  [ -z "$touch_id" ] && continue
  touch_device="$(xinput list --name-only "$touch_id" 2>/dev/null || echo "touchscreen")"

  xinput enable "$touch_id" >/dev/null 2>&1 || true
  xinput set-prop "$touch_id" 'Device Enabled' 1 >/dev/null 2>&1 || true

  if xinput list-props "$touch_id" | grep -q 'libinput Send Events Mode Enabled'; then
    xinput set-prop "$touch_id" 'libinput Send Events Mode Enabled' 0 0 \
      >/dev/null 2>&1 || true
  fi

  # Bersihkan kalibrasi lama sebelum map-to-output menghitung matriks baru.
  xinput set-prop "$touch_id" 'Coordinate Transformation Matrix' \
    1 0 0 0 1 0 0 0 1 >/dev/null 2>&1 || true

  map_error="$(xinput map-to-output "$touch_id" "$touch_output" 2>&1)"
  if [ $? -eq 0 ]; then
    echo "[TOUCH] '$touch_device' dipetakan ke $touch_output."
    configured=$((configured + 1))
  else
    echo "[TOUCH] Gagal memetakan '$touch_device' (id=$touch_id): $map_error"
  fi

  if [ -n "${TOUCH_MATRIX:-}" ]; then
    # TOUCH_MATRIX berisi sembilan angka Coordinate Transformation Matrix.
    read -r -a matrix_values <<< "$TOUCH_MATRIX"
    xinput set-prop "$touch_id" 'Coordinate Transformation Matrix' \
      "${matrix_values[@]}" >/dev/null 2>&1 || true
  fi
done <<< "$touch_ids"

if [ "$configured" -eq 0 ]; then
  echo "[TOUCH] Perangkat ditemukan tetapi gagal dipetakan ke $touch_output."
fi
