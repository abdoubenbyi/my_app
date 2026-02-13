import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:share_plus/share_plus.dart';
import '../models/cheat_sheet.dart';
import '../services/favorites_service.dart';
import '../utils/color_utils.dart';
import '../utils/ad_service.dart';
import '../widgets/markdown_table_builder.dart';

class DetailScreen extends StatefulWidget {
  final CheatSheet sheet;

  const DetailScreen({super.key, required this.sheet});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final isFav = await favoritesService.isFavorite(widget.sheet.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    await favoritesService.toggleFavorite(widget.sheet.id);
    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'Added to favorites' : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareContent(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;

    Share.share(
      'Check out this ${widget.sheet.title} cheatsheet on DevSheets!\n\n${widget.sheet.intro}\n\nDownload the app:\nhttps://play.google.com/store/apps/details?id=com.abdoudev.devsheets',
      subject: 'DevSheets: ${widget.sheet.title}',
      sharePositionOrigin: box != null
          ? (box.localToGlobal(Offset.zero) & box.size)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor = getBrandColor(widget.sheet.backgroundHex);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Show ad and then pop
        adService.showRewardedVideoAd(
          onAdClosed: () {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        );
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 200,
              backgroundColor: brandColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  adService.showRewardedVideoAd(
                    onAdClosed: () {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
              actions: [
                Builder(
                  builder: (context) {
                    return IconButton(
                      onPressed: () => _shareContent(context),
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Share',
                    );
                  },
                ),
                IconButton(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: Colors.white,
                  ),
                  tooltip: _isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: brandColor,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 20),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: SvgPicture.asset(
                        widget.sheet.iconPath,
                        width: 64,
                        height: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sheet.title,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.sheet.tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.sheet.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: brandColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: isDark
                                        ? brandColor
                                        : brandColor.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 24),
                    MarkdownBody(
                      data: widget.sheet.content,
                      selectable: true,
                      builders: {
                        'table': MarkdownTableBuilder(context),
                        'pre': CodeBlockBuilder(context, isDark),
                      },
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: const TextStyle(fontSize: 16, height: 1.6),
                            tableHead: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            tableBody: GoogleFonts.outfit(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            // We handle code block styling in the builder now, but keep this for inline code reference
                            code: GoogleFonts.firaCode(
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : Colors.black.withValues(alpha: 0.05),
                              color: isDark
                                  ? const Color(0xFF38BDF8)
                                  : Colors.blue.shade700,
                              fontSize: 14,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final bool isDark;

  CodeBlockBuilder(this.context, this.isDark);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Determine content
    final String content = element.textContent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                content,
                style: GoogleFonts.firaCode(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white,
                foregroundColor: isDark ? Colors.white70 : Colors.black54,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied to clipboard'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
