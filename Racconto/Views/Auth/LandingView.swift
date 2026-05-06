import SwiftUI

struct LandingView: View {
    var authViewModel: AuthViewModel
    @State private var currentPage = 0
    @State private var showLogin = false
    @Environment(\.openURL) private var openURL

    private let registerURL = URL(string: "https://racconto.app/register")!
    private let pageCount = 4

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                heroPage.tag(0)
                featurePage(
                    number: "01",
                    title: "챕터로 스토리 구성하기",
                    desc: "챕터와 서브 챕터로 시작과 끝의 흐름을 구성하고, 사진 블록과 텍스트 블록을 유기적으로 연결하여 이야기를 만드세요. 완성된 스토리는 공개 포트폴리오로 공유됩니다.",
                    visual: storyVisual
                ).tag(1)
                featurePage(
                    number: "02",
                    title: "손쉬운 사진 분류 & 선별",
                    desc: "별점과 컬러 레이블로 사진을 빠르게 분류하고, 챕터에 배치하세요. EXIF 메타데이터를 자동으로 읽어 들이고, 라이트박스에서 한 장씩 세밀하게 확인할 수 있습니다.",
                    visual: photosVisual
                ).tag(2)
                featurePage(
                    number: "03",
                    title: "마크다운 프로젝트 노트",
                    desc: "프로젝트의 컨셉과 아이디어, 리서치 내용을 마크다운으로 기록하세요. 고정 노트, 개별 사진 연결을 지원하고, 기록이 더 풍부한 이야기의 바탕이 됩니다.",
                    visual: notesVisual
                ).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            bottomOverlay
        }
        .sheet(isPresented: $showLogin) {
            LoginView(authViewModel: authViewModel)
        }
    }

    // MARK: - Hero Page

    private var heroPage: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            // 배경 격자 장식
            GeometryReader { geo in
                Canvas { context, size in
                    let spacing: CGFloat = 56
                    let color = Color.primary.opacity(0.04)
                    var x: CGFloat = 0
                    while x <= size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(color), lineWidth: 1)
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(color), lineWidth: 1)
                        y += spacing
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Text("스마트폰부터 필름까지, 모든 사진가를 위해")
                        .font(.caption)
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 4) {
                        Text("당신의 사진이")
                            .font(.custom("Georgia", size: 40))
                            .fontWeight(.bold)
                        Text("이야기가 됩니다")
                            .font(.custom("Georgia", size: 40))
                            .fontWeight(.bold)
                    }
                    .multilineTextAlignment(.center)

                    Text("프레임 속 시간을 이어 스토리를 만드세요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("무료 오픈 베타")
                        .font(.caption2)
                        .tracking(1.5)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(20)
                }
                .padding(.horizontal, 40)

                Spacer()
                Spacer()
            }
        }
    }

    // MARK: - Feature Page

    private func featurePage(number: String, title: String, desc: String, visual: some View) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                visual
                    .padding(.horizontal, 24)
                    .padding(.top, 64)
                    .padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 10) {
                    Text(number)
                        .font(.system(.caption, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(.tertiary)

                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    // MARK: - Feature Visuals

    private var storyVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color(red: 0.35, green: 0.3, blue: 0.85), Color(red: 0.55, green: 0.25, blue: 0.75)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 220)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.95))
                        Text("챕터 1. 도입")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("챕터 2. 전개")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("챕터 3. 결말")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1)
                    .padding(.vertical, 24)

                VStack(spacing: 12) {
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("포트폴리오")
                        .font(.caption2)
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 28)
        }
    }

    private var photosVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color(red: 0.95, green: 0.5, blue: 0.15), Color(red: 0.98, green: 0.72, blue: 0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 220)

            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(i == 0 ? 0.9 : 0.4 - Double(i) * 0.08))
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.6))
                            )
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { n in
                            Image(systemName: n <= 4 ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(n <= 4 ? 0.9 : 0.4))
                        }
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(["red", "orange", "yellow"], id: \.self) { _ in
                            Circle()
                                .fill(.white.opacity(0.7))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private var notesVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color(red: 0.1, green: 0.6, blue: 0.55), Color(red: 0.15, green: 0.75, blue: 0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 220)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.95))
                    Spacer()
                    Image(systemName: "pin.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 6) {
                    mdLine("# 프로젝트 컨셉", opacity: 0.95)
                    mdLine("**주제:** 도시의 빛과 그림자", opacity: 0.8)
                    mdLine("*촬영 아이디어를 기록하세요*", opacity: 0.65)
                    mdLine("- 새벽 5시, 골목 끝 빛줄기", opacity: 0.55)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private func mdLine(_ text: String, opacity: Double) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.white.opacity(opacity))
    }

    // MARK: - Bottom Overlay

    private var bottomOverlay: some View {
        VStack(spacing: 16) {
            // 페이지 인디케이터
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: i == currentPage ? 20 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            // CTA
            Button {
                openURL(registerURL)
            } label: {
                Text("Racconto 시작하기")
                    .font(.body)
                    .fontWeight(.semibold)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.primary)
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .cornerRadius(8)
            }

            Button {
                showLogin = true
            } label: {
                Text("이미 계정이 있으신가요? 로그인")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 48)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.35)
            )
            .ignoresSafeArea()
        )
    }
}
