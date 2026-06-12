import type { BridgeReceiveFunction, FocusFunction, ThemeFunction } from "./bridge/types";

declare global {
  interface Window {
    InputoInitialTheme?: string;
    InputoNativeThemeSet?: ThemeFunction;
    InputoNativeBridgeReceiveBase64?: BridgeReceiveFunction;
    InputoComposerFocus?: FocusFunction;
    webkit?: {
      messageHandlers?: {
        inputoNative?: {
          postMessage(message: string): void;
        };
      };
    };
  }
}
