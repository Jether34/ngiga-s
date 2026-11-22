import { useState, useEffect, useRef } from "react";
import { ScanLine, Camera, ArrowRight, QrCode } from "lucide-react";
import { Field } from "../components/ui";

export function ScanCapture({
  onCode,
  label = "Enter item code",
  placeholder = "e.g. CAM-R50-001",
  actionLabel = "Look up item",
}) {
  const [code, setCode] = useState("");
  const [cameraState, setCameraState] = useState("idle");
  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const detectorRef = useRef(null);
  const requestRef = useRef(0);
  const stop = () => {
    requestRef.current += 1;
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
    if (videoRef.current) videoRef.current.srcObject = null;
    detectorRef.current = null;
    setCameraState("idle");
  };
  useEffect(
    () => () => {
      requestRef.current += 1;
      streamRef.current?.getTracks().forEach((track) => track.stop());
      if (videoRef.current) videoRef.current.srcObject = null;
    },
    [],
  );
  const start = async () => {
    if (cameraState === "requesting" || cameraState === "scanning" || cameraState === "preview") return;
    if (!navigator.mediaDevices?.getUserMedia) {
      setCameraState("unavailable");
      return;
    }
    const request = ++requestRef.current;
    setCameraState("requesting");
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "environment" },
        audio: false,
      });
      if (request !== requestRef.current) {
        stream.getTracks().forEach((track) => track.stop());
        return;
      }
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
      if (request !== requestRef.current) return;
      if ("BarcodeDetector" in window) {
        detectorRef.current = new window.BarcodeDetector({
          formats: ["qr_code", "code_128", "code_39", "ean_13"],
        });
        setCameraState("scanning");
      } else setCameraState("preview");
    } catch (error) {
      if (request !== requestRef.current) return;
      streamRef.current?.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
      if (videoRef.current) videoRef.current.srcObject = null;
      setCameraState(
        error.name === "NotAllowedError" ? "denied" : "unavailable",
      );
    }
  };
  useEffect(() => {
    if (cameraState !== "scanning") return;
    let canceled = false;
    let detecting = false;
    const timer = setInterval(async () => {
      if (!videoRef.current || !detectorRef.current || canceled || detecting) return;
      detecting = true;
      try {
        const found = await detectorRef.current.detect(videoRef.current);
        if (canceled) return;
        if (found[0]?.rawValue) {
          canceled = true;
          setCode(found[0].rawValue);
          onCode(found[0].rawValue);
          stop();
        }
      } catch {
        /* keep manual entry available */
      } finally {
        detecting = false;
      }
    }, 500);
    return () => {
      canceled = true;
      clearInterval(timer);
    };
  }, [cameraState, onCode]);
  return (
    <div className="scan-capture">
      <div
        className={`camera-box ${cameraState === "scanning" || cameraState === "preview" ? "camera-live" : ""}`}
      >
        <video ref={videoRef} playsInline muted aria-label="Camera preview" />
        <div className="camera-overlay">
          <div className="scan-frame">
            <span />
            <span />
            <span />
            <span />
            <ScanLine size={48} strokeWidth={1.2} />
          </div>
          <strong>
            {cameraState === "scanning"
              ? "Hold the code inside the frame"
              : cameraState === "preview"
                ? "Camera ready, decoder unavailable"
                : "Scan an item code"}
          </strong>
          <small>
            {cameraState === "idle"
              ? "Allow camera access to scan a QR or barcode"
              : cameraState === "requesting"
                ? "Requesting camera permission…"
                : cameraState === "preview"
                  ? "Use manual entry below on this browser."
                  : cameraState === "denied"
                    ? "Camera permission denied. Manual entry still works."
                    : cameraState === "unavailable"
                      ? "Camera unavailable. Manual entry still works."
                      : "Keep the label steady and well lit."}
          </small>
        </div>
      </div>
      <div className="scan-camera-actions">
        {cameraState === "scanning" || cameraState === "preview" ? (
          <button className="button secondary" onClick={stop}>
            Stop camera
          </button>
        ) : (
          <button
            className="button secondary"
            onClick={start}
            disabled={cameraState === "requesting"}
          >
            <Camera size={17} />{" "}
            {cameraState === "requesting" ? "Opening camera…" : "Open camera"}
          </button>
        )}
      </div>
      <div className="manual-divider">
        <span>OR ENTER MANUALLY</span>
      </div>
      <form
        onSubmit={(event) => {
          event.preventDefault();
          if (code.trim()) onCode(code.trim());
        }}
      >
        <Field label={label}>
          <div className="manual-input">
            <QrCode size={19} />
            <input
              value={code}
              onChange={(event) => setCode(event.target.value)}
              placeholder={placeholder}
              aria-label={label}
            />
          </div>
        </Field>
        <button className="button wide" disabled={!code.trim()}>
          {actionLabel} <ArrowRight size={17} />
        </button>
      </form>
    </div>
  );
}
