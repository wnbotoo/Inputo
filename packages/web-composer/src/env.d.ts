import type { ThemeName } from "@inputo/bridge-contracts";
import type { BridgeReceiveFunction } from "./shared/bridge/bridgeClient";

export type ThemeFunction = (theme: ThemeName | string) => void;
export type FocusFunction = () => void;

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
