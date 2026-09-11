import type { SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement>;

function base(children: React.ReactNode, props: IconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      {...props}
    >
      {children}
    </svg>
  );
}

export const IconDashboard = (p: IconProps) =>
  base(
    <>
      <rect x="3" y="3" width="7" height="9" rx="1.5" />
      <rect x="14" y="3" width="7" height="5" rx="1.5" />
      <rect x="14" y="12" width="7" height="9" rx="1.5" />
      <rect x="3" y="16" width="7" height="5" rx="1.5" />
    </>,
    p
  );

export const IconUpload = (p: IconProps) =>
  base(
    <>
      <path d="M12 16V4" />
      <path d="M6.5 9.5 12 4l5.5 5.5" />
      <path d="M4 16.5V19a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2.5" />
    </>,
    p
  );

export const IconQueue = (p: IconProps) =>
  base(
    <>
      <path d="M4 6h16" />
      <path d="M4 12h10" />
      <path d="M4 18h16" />
      <circle cx="19" cy="12" r="1.6" />
    </>,
    p
  );

export const IconPalette = (p: IconProps) =>
  base(
    <>
      <path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.8-.9 1.8-1.8 0-.5-.2-.9-.5-1.2-.3-.3-.5-.7-.5-1.2 0-.9.7-1.6 1.6-1.6H16a4 4 0 0 0 4-4c0-4.4-3.6-8.2-8-8.2Z" />
      <circle cx="7.5" cy="10.5" r="1" fill="currentColor" stroke="none" />
      <circle cx="11" cy="7" r="1" fill="currentColor" stroke="none" />
      <circle cx="15.5" cy="8" r="1" fill="currentColor" stroke="none" />
    </>,
    p
  );

export const IconSettings = (p: IconProps) =>
  base(
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09A1.65 1.65 0 0 0 15 4.6a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z" />
    </>,
    p
  );

export const IconCheck = (p: IconProps) => base(<path d="M20 6 9 17l-5-5" />, p);

export const IconX = (p: IconProps) =>
  base(
    <>
      <path d="M18 6 6 18" />
      <path d="M6 6l12 12" />
    </>,
    p
  );

export const IconExternalLink = (p: IconProps) =>
  base(
    <>
      <path d="M14 4h6v6" />
      <path d="M10 14 20 4" />
      <path d="M18 13v5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h5" />
    </>,
    p
  );

export const IconClapperboard = (p: IconProps) =>
  base(
    <>
      <path d="M4 8.5 5.5 4h13L20 8.5" />
      <rect x="4" y="8.5" width="16" height="11" rx="1.5" />
      <path d="m7 4 2 4.5M12 4l2 4.5M17 4l2 4.5" />
    </>,
    p
  );

export const IconScissors = (p: IconProps) =>
  base(
    <>
      <circle cx="6" cy="6" r="2.2" />
      <circle cx="6" cy="18" r="2.2" />
      <path d="M8.5 7.5 20 19" />
      <path d="M20 5 8.5 16.5" />
    </>,
    p
  );

export const IconGear = IconSettings;

export const IconAlertTriangle = (p: IconProps) =>
  base(
    <>
      <path d="M10.3 3.9 2.6 18a1.5 1.5 0 0 0 1.3 2.2h16.2a1.5 1.5 0 0 0 1.3-2.2L13.7 3.9a1.5 1.5 0 0 0-2.6 0Z" />
      <path d="M12 9.5v4" />
      <path d="M12 16.5h.01" />
    </>,
    p
  );

export const IconUploadCloud = (p: IconProps) =>
  base(
    <>
      <path d="M7.5 17.5a4.5 4.5 0 0 1-.6-8.96A5.5 5.5 0 0 1 17.4 9.3 4 4 0 0 1 17 17.5" />
      <path d="M12 12v7" />
      <path d="M9.5 14.5 12 12l2.5 2.5" />
    </>,
    p
  );

export const IconDatabase = (p: IconProps) =>
  base(
    <>
      <ellipse cx="12" cy="5.5" rx="8" ry="2.5" />
      <path d="M4 5.5V18c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5V5.5" />
      <path d="M4 12c0 1.4 3.6 2.5 8 2.5s8-1.1 8-2.5" />
    </>,
    p
  );

export const IconPlug = (p: IconProps) =>
  base(
    <>
      <path d="M9 3v5M15 3v5" />
      <path d="M6.5 8h11l-.7 5.5a5 5 0 0 1-4.96 4.5h-.68a5 5 0 0 1-4.96-4.5L6.5 8Z" />
      <path d="M12 18v3" />
    </>,
    p
  );

export const IconSparkles = (p: IconProps) =>
  base(
    <>
      <path d="M12 3v4M12 17v4M4 12h4M16 12h4" />
      <path d="m6.5 6.5 2 2M15.5 15.5l2 2M17.5 6.5l-2 2M8.5 15.5l-2 2" />
      <circle cx="12" cy="12" r="2.5" />
    </>,
    p
  );

export const IconCopyStyle = (p: IconProps) =>
  base(
    <>
      <rect x="4" y="7" width="12" height="14" rx="1.75" />
      <path d="M9 7V5.75A1.75 1.75 0 0 1 10.75 4h7.5A1.75 1.75 0 0 1 20 5.75v10.5A1.75 1.75 0 0 1 18.25 18H16" />
    </>,
    p
  );

export const IconLogOut = (p: IconProps) =>
  base(
    <>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <path d="M16 17 21 12l-5-5" />
      <path d="M21 12H9" />
    </>,
    p
  );

export const IconTrendingUp = (p: IconProps) =>
  base(
    <>
      <path d="m3 17 6-6 4 4 8-8" />
      <path d="M15 6h6v6" />
    </>,
    p
  );

export const IconEye = (p: IconProps) =>
  base(
    <>
      <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z" />
      <circle cx="12" cy="12" r="3" />
    </>,
    p
  );

export const IconClock = (p: IconProps) =>
  base(
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3.5 2" />
    </>,
    p
  );

export const IconHeart = (p: IconProps) =>
  base(
    <path d="M12 20.5s-7-4.35-9.5-8.7C.8 8.6 2.2 5 5.6 5c1.9 0 3.3 1 4.4 2.6C11.1 6 12.5 5 14.4 5c3.4 0 4.8 3.6 3.1 6.8C19.5 15.65 12 20.5 12 20.5Z" />,
    p
  );

export const IconMessageCircle = (p: IconProps) =>
  base(<path d="M21 11.5a8.5 8.5 0 0 1-8.5 8.5c-1.35 0-2.6-.32-3.7-.9L3 20l1.05-4.2A8.5 8.5 0 1 1 21 11.5Z" />, p);

export const IconDownload = (p: IconProps) =>
  base(
    <>
      <path d="M12 4v12" />
      <path d="M6.5 10.5 12 16l5.5-5.5" />
      <path d="M4 19.5h16" />
    </>,
    p
  );

export const IconPlay = (p: IconProps) =>
  base(<path d="M7 4.5v15l13-7.5-13-7.5Z" />, p);

export const IconUsers = (p: IconProps) =>
  base(
    <>
      <circle cx="9" cy="8" r="3.2" />
      <path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6" />
      <path d="M16 4.2c1.6.4 2.8 1.9 2.8 3.6 0 1.7-1.2 3.2-2.8 3.6" />
      <path d="M21.5 20c0-3-2-5.2-4.8-5.8" />
    </>,
    p
  );

export const IconWorld = (p: IconProps) =>
  base(
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18" />
      <path d="M12 3c2.6 2.6 4 5.7 4 9s-1.4 6.4-4 9c-2.6-2.6-4-5.7-4-9s1.4-6.4 4-9Z" />
    </>,
    p
  );

export const IconFlame = (p: IconProps) =>
  base(
    <path d="M12 2.5c1 2.5-1.5 3.8-1.5 6 0 1.2 1 2 2 2 1.3 0 2-1.1 2-2.2 2.2 1.6 3.5 4.1 3.5 6.7 0 4-3.1 7-6.5 7S5 19 5 15c0-3.4 2-5.7 3.3-7.3.5-.6 1.1-1.3 1.4-2.1.4-1 .4-2 .3-3.1Z" />,
    p
  );
