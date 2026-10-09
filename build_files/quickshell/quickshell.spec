# PugPal's Quickshell, built from a pinned upstream commit in the Containerfile's
# quickshell-builder stage (against the exact Qt this image ships - Quickshell
# uses Qt private APIs, so it must be rebuilt whenever Qt changes; the daily CI
# build does that). Adapted from AvengeMedia/danklinux's quickshell-git.spec.
#
# Bump: change `commit` (Renovate opens PRs for it), keep `tag` at the latest
# upstream release tag.

# renovate: datasource=git-refs depName=https://github.com/quickshell-mirror/quickshell currentValue=master
%global commit      4f508be500dea6e5732cc3d50382a0048b17e7b1
%global tag         0.3.2
%global shortcommit %(c=%{commit}; echo ${c:0:7})

Name:               quickshell
Version:            %{tag}^git%{shortcommit}
Release:            1.pugpal%{?dist}
Summary:            Flexible QtQuick based desktop shell toolkit (PugPal build)
License:            LGPL-3.0-only AND GPL-3.0-only
URL:                https://github.com/quickshell-mirror/quickshell
Source0:            %{url}/archive/%{commit}/quickshell-%{commit}.tar.gz

BuildRequires:      cmake
BuildRequires:      cmake(Qt6Core)
BuildRequires:      cmake(Qt6Qml)
BuildRequires:      cmake(Qt6ShaderTools)
BuildRequires:      cmake(Qt6WaylandClient)
BuildRequires:      gcc-c++
BuildRequires:      ninja-build
BuildRequires:      pkgconfig(CLI11)
BuildRequires:      pkgconfig(gbm)
BuildRequires:      pkgconfig(glib-2.0)
BuildRequires:      pkgconfig(jemalloc)
BuildRequires:      pkgconfig(libdrm)
BuildRequires:      pkgconfig(libpipewire-0.3)
BuildRequires:      pkgconfig(pam)
BuildRequires:      pkgconfig(polkit-agent-1)
BuildRequires:      pkgconfig(wayland-client)
BuildRequires:      pkgconfig(wayland-protocols)
BuildRequires:      qt6-qtbase-private-devel
BuildRequires:      spirv-tools

Provides:           desktop-notification-daemon

%description
Flexible toolkit for making desktop shells with QtQuick, targeting Wayland
and X11. Built by PugPal from upstream commit %{commit}.

%prep
%autosetup -n quickshell-%{commit} -p1

%build
# Crash handler off: it needs cpptrace, which Fedora doesn't package.
%cmake -GNinja \
       -DBUILD_SHARED_LIBS=OFF \
       -DCRASH_HANDLER=OFF \
       -DUSE_JEMALLOC=ON \
       -DCMAKE_BUILD_TYPE=Release \
       -DDISTRIBUTOR="PugPal (built from source)" \
       -DGIT_REVISION=%{commit} \
       -DINSTALL_QML_PREFIX=%{_lib}/qt6/qml
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%license LICENSE-GPL
%doc README.md
%{_bindir}/qs
%{_bindir}/quickshell
%{_datadir}/applications/org.quickshell.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.quickshell.svg
%{_libdir}/qt6/qml/Quickshell
