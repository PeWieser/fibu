import { useCallback, useRef, useState } from "react";
import UploadScreen from "./components/UploadScreen";
import CropEditor from "./components/CropEditor";

export default function App() {
  const [img, setImg] = useState<HTMLImageElement | null>(null);
  const [name, setName] = useState("bild");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const urlRef = useRef<string>("");

  const handleFile = useCallback(async (file: File) => {
    if (!file.type.startsWith("image/") && !/\.(heic|heif)$/i.test(file.name)) {
      setError("Das ist keine Bilddatei.");
      return;
    }
    setError(null);
    setLoading(true);
    if (urlRef.current) URL.revokeObjectURL(urlRef.current);
    const url = URL.createObjectURL(file);
    urlRef.current = url;
    const image = new Image();
    image.decoding = "async";
    image.src = url;
    try {
      await image.decode();
      if (!image.naturalWidth) throw new Error("leer");
      setName(file.name || "bild");
      setImg(image);
    } catch {
      setError(
        "Dieses Bildformat kann der Browser leider nicht öffnen (z. B. HEIC). Bitte JPG, PNG oder WebP verwenden.",
      );
      URL.revokeObjectURL(url);
      urlRef.current = "";
    } finally {
      setLoading(false);
    }
  }, []);

  const reset = () => {
    if (urlRef.current) URL.revokeObjectURL(urlRef.current);
    urlRef.current = "";
    setImg(null);
  };

  if (img) {
    return (
      <CropEditor
        key={img.src}
        img={img}
        fileName={name}
        onReset={reset}
      />
    );
  }

  return (
    <>
      <UploadScreen onFile={handleFile} error={error} />
      {loading && (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/60 text-sm text-white/80 backdrop-blur-sm">
          Bild wird geladen …
        </div>
      )}
    </>
  );
}
