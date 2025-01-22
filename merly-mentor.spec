Release:        1%{?dist}
Summary:        Merly Mentor code quality and security analysis tool

License:        Proprietary
URL:            https://github.com/merly-ai/merly-mentor
Source0:        ./%{name}-%{version}.tar.gz

# Runtime dependencies
Requires:       nodejs >= 20.0
Requires:       systemd
Requires:       git

# BuildRoot
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
Merly Mentor is a code quality and security analysis tool that provides actionable insights to developers.

%global debug_package %{nil}

%prep
%setup -q

%build
# No build step required for this package

%install
# Create installation directories
mkdir -p %{buildroot}/opt/merly-mentor
mkdir -p %{buildroot}/etc/systemd/system

# Copy application files to /opt/merly-mentor
cp -r MerlyMentor MentorBridge UI scripts .models .assets .mentor %{buildroot}/opt/merly-mentor

# Adjust file permissions
chmod -R 755 %{buildroot}/opt/merly-mentor


# Install systemd service files
cat > %{buildroot}/etc/systemd/system/mentor-ui.service << EOF
[Unit]
Description=Merly Mentor UI Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/merly-mentor/UI
ExecStart=/usr/bin/npm start
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

cat > %{buildroot}/etc/systemd/system/mentor-bridge.service << EOF
[Unit]
Description=Merly Mentor Bridge Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/merly-mentor
ExecStart=/opt/merly-mentor/MentorBridge
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

cat > %{buildroot}/etc/systemd/system/mentor-daemon.service << EOF
[Unit]
Description=Merly Mentor Daemon Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/merly-mentor
ExecStart=/opt/merly-mentor/MerlyMentor -N daemon --stdout
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

%post
# Enable all services
systemctl daemon-reload
systemctl enable mentor-ui.service
systemctl enable mentor-bridge.service
systemctl enable mentor-daemon.service


%files
%defattr(-,root,root,-)
/opt/merly-mentor
/etc/systemd/system/mentor-ui.service
/etc/systemd/system/mentor-bridge.service
/etc/systemd/system/mentor-daemon.service

%changelog
* Mon Jan 21 2025 Saif Zaman <saif.zaman@merly.ai> - 1.0.0-1
- Initial RPM package for Merly Mentor services
