import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yaml/yaml.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:startapp_sdk/startapp.dart';
import '../models/cheat_sheet.dart';
import '../utils/color_utils.dart';
import '../utils/ad_service.dart';
import '../services/favorites_service.dart';
import 'detail_screen.dart';

class CatalogueScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  const CatalogueScreen({super.key, required this.onThemeToggle});

  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  List<CheatSheet> _allSheets = [];
  List<CheatSheet> _filteredSheets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final Set<String> _selectedTags = {};
  Set<String> _allTags = {};
  bool _showFavoritesOnly = false;
  List<String> _favoriteIds = [];
  StartAppBannerAd? _bannerAd;

  final ScrollController _scrollController = ScrollController();
  int _itemLimit = 20;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadData();
    _loadBanner();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_itemLimit < _filteredSheets.length) {
        setState(() {
          _itemLimit += _pageSize;
        });
      }
    }
  }

  void _loadBanner() {
    adService
        .loadBannerAd(StartAppBannerType.BANNER)
        .then((ad) {
          if (mounted) {
            setState(() => _bannerAd = ad);
          }
        })
        .catchError((e) {
          debugPrint('Error loading banner: $e');
        });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favs = await favoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _favoriteIds = favs;
      });
      // Re-filter if we are currently showing content
      if (!_isLoading) _filter();
    }
  }

  Future<void> _loadData() async {
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(
        rootBundle,
      );
      final allAssets = manifest.listAssets();

      final postPaths = allAssets
          .where(
            (String key) =>
                key.toLowerCase().contains('posts/') && key.endsWith('.md'),
          )
          .toList();

      final Set<String> tagsSet = {};
      int count = 0;

      for (final path in postPaths) {
        try {
          final content = await rootBundle.loadString(path);
          final parsed = _parseSheet(path, content);
          if (parsed != null) {
            _allSheets.add(parsed);
            tagsSet.addAll(parsed.tags);
            count++;

            // Initial batch to show something immediately
            if (count == 10) {
              if (mounted) {
                setState(() {
                  _filteredSheets = List.from(_allSheets);
                  _allTags = Set.from(tagsSet);
                  _isLoading = false;
                });
              }
            } else if (count % 30 == 0) {
              // Periodic updates for background loading
              if (mounted) {
                setState(() {
                  _filter(); // Update filtered list with new data
                  _allTags = Set.from(tagsSet);
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading asset $path: $e');
        }
      }

      _allSheets.sort((a, b) => a.title.compareTo(b.title));

      if (mounted) {
        setState(() {
          _filter();
          _allTags = tagsSet;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading manifest: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  CheatSheet? _parseSheet(String path, String rawContent) {
    try {
      final fileName = path.split('/').last;
      final id = fileName.replaceAll('.md', '');

      final regex = RegExp(r'^---\n(.*?)\n---\n(.*)', dotAll: true);
      final match = regex.firstMatch(rawContent);

      Map<String, dynamic> metadata = {};
      String markdownBody = rawContent;

      if (match != null) {
        final yamlStr = match.group(1);
        markdownBody = match.group(2) ?? '';
        try {
          final yamlMap = loadYaml(yamlStr!);
          if (yamlMap is Map) {
            metadata = Map<String, dynamic>.from(yamlMap);
          } else if (yamlMap is YamlMap) {
            metadata = Map<String, dynamic>.from(yamlMap);
          }
        } catch (e) {
          debugPrint('Error parsing yaml for $id: $e');
        }

        // Clean up CSS-like markers commonly found in these specific markdown files
        markdownBody = markdownBody.replaceAll(RegExp(r'\{.show-header\}'), '');
        markdownBody = markdownBody.replaceAll(RegExp(r'\{.cols-\d\}'), '');
      }

      final title = metadata['title'] as String? ?? id;

      final tagsList = metadata['tags'];
      final categoriesList = metadata['categories'];
      final Set<String> combinedTags = {};

      if (tagsList is List) {
        combinedTags.addAll(
          tagsList
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty),
        );
      }
      if (categoriesList is List) {
        combinedTags.addAll(
          categoriesList
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty),
        );
      }

      final tags = combinedTags.toList();
      final intro = metadata['intro']?.toString().trim() ?? '';

      String? bgHex;
      final bgString = metadata['background'] as String?;
      if (bgString != null &&
          bgString.startsWith('bg-[#') &&
          bgString.endsWith(']')) {
        bgHex = bgString.substring(4, bgString.length - 1);
      }

      final iconPath = 'assets/icons/$id.svg';

      return CheatSheet(
        id: id,
        title: title,
        tags: tags,
        intro: intro,
        content: markdownBody,
        backgroundHex: bgHex,
        iconPath: iconPath,
      );
    } catch (e) {
      debugPrint('Error parsing sheet $path: $e');
      return null;
    }
  }

  void _filter() {
    setState(() {
      _filteredSheets = _allSheets.where((sheet) {
        final matchesSearch =
            sheet.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            sheet.tags.any(
              (t) => t.toLowerCase().contains(_searchQuery.toLowerCase()),
            );

        final matchesTags =
            _selectedTags.isEmpty ||
            _selectedTags.every((t) => sheet.tags.contains(t));

        final matchesFavorites =
            !_showFavoritesOnly || _favoriteIds.contains(sheet.id);

        return matchesSearch && matchesTags && matchesFavorites;
      }).toList();
      _itemLimit = _pageSize; // Reset pagination on filter
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isDark)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              sliver: _isLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildGrid(isDark),
            ),
            SliverToBoxAdapter(child: _buildFooter(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Divider(
            color: isDark ? Colors.white10 : Colors.black12,
            thickness: 1,
          ),
          const SizedBox(height: 20),
          Text(
            'Credits to',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse(
                'https://github.com/Fechin/reference/tree/main',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Fechin/reference',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF38BDF8),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Original content & visual snippets',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                ).createShader(bounds),
                child: Text(
                  'DevSheets',
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: widget.onThemeToggle,
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your ultimate developer cheatsheet library.',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
          if (_bannerAd != null) ...[
            const SizedBox(height: 24),
            Center(child: StartAppBanner(_bannerAd!)),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black12,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (val) {
                      _searchQuery = val;
                      _filter();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search tech...',
                      icon: const Icon(Icons.search_rounded),
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: () {
                  setState(() {
                    _showFavoritesOnly = !_showFavoritesOnly;
                    _filter();
                  });
                },
                style: IconButton.styleFrom(
                  backgroundColor: _showFavoritesOnly
                      ? const Color(0xFFFF4081)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white),
                  foregroundColor: _showFavoritesOnly
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      20,
                    ), // Matching search bar radius
                    side: BorderSide(
                      color: _showFavoritesOnly
                          ? Colors.transparent
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black12),
                    ),
                  ),
                  fixedSize: const Size(56, 56), // Matching height approx
                ),
                icon: Icon(
                  _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTagsBar(isDark),
        ],
      ),
    );
  }

  Widget _buildTagsBar(bool isDark) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _allTags.map((tag) {
          final isSelected = _selectedTags.contains(tag);
          final primary = Theme.of(context).colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                  _filter();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary
                      : isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black12,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : isDark
                        ? Colors.white70
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid(bool isDark) {
    if (_filteredSheets.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text("No cheatsheets found")),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final sheet = _filteredSheets[index];
          final brandColor = getBrandColor(sheet.backgroundHex);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailScreen(sheet: sheet)),
              ).then((_) => _loadFavorites());
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? brandColor.withValues(alpha: 0.1)
                            : brandColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: SvgPicture.asset(
                            sheet.iconPath,
                            width: 32,
                            height: 32,
                            placeholderBuilder: (_) =>
                                Icon(Icons.code, color: brandColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sheet.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sheet.intro,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 12,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: _filteredSheets.length > _itemLimit
            ? _itemLimit
            : _filteredSheets.length,
      ),
    );
  }
}
