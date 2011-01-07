#!/usr/bin/perl

# save this file in << UTF-8  >> encode !
# ******************************************************
# Software name : Make Thumbnail HTML （サムネイルHTML作成）
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# thumbnail-dir.pl
# version 1.1 (2010/November/23)
#
# GNU GPL Free Software
#
# このプログラムはフリーソフトウェアです。あなたはこれを、フリーソフトウェア財
# 団によって発行された GNU 一般公衆利用許諾契約書(バージョン2か、希望によっては
# それ以降のバージョンのうちどれか)の定める条件の下で再頒布または改変することが
# できます。
# 
# このプログラムは有用であることを願って頒布されますが、*全くの無保証* です。
# 商業可能性の保証や特定の目的への適合性は、言外に示されたものも含め全く存在し
# ません。詳しくはGNU 一般公衆利用許諾契約書をご覧ください。
# 
# あなたはこのプログラムと共に、GNU 一般公衆利用許諾契約書の複製物を一部受け取
# ったはずです。もし受け取っていなければ、フリーソフトウェア財団まで請求してく
# ださい(宛先は the Free Software Foundation, Inc., 59 Temple Place, Suite 330
# , Boston, MA 02111-1307 USA)。
#
# http://www.opensource.jp/gpl/gpl.ja.html
# ******************************************************

use strict;
use warnings;

use Switch;
use File::Find::Rule;
use File::Basename;
use Image::Magick;
use Image::ExifTool;
use Image::Size;

use Data::Dumper;

my $strBaseDir = './';		# 基準ディレクトリ
my $strImageRelativeDir = '';		# 画像ディレクトリを1つに限定する場合に利用
my $strThumbRelativeDir = 'thumb/';	# サムネイル格納ディレクトリ
my $strOutputHTML = "index.html";	# 出力HTML（基準ディレクトリに出力）
my $nHtmlGrid = 0;		# HTMLのグリッドカラム数（0は説明文付き1列）
my $nLongEdge = 150;		# サムネイルの長辺ピクセル数（ImageMagickで縮小時に利用）
my $nFindMinDepth = 2;		# File::Find::Ruleでの検索深さ（デフォルトは1段目のみ）
my $nFindMaxDepth = 2;		# File::Find::Ruleでの検索深さ（デフォルトは1段目のみ）

my $flag_overwrite = 0;		# サムネイルを作成するときに、既存ファイルに上書きするフラグ
my $flag_verbose = 0;		# 詳細表示するフラグ
my $flag_sort_order = 'file-name';	# ソート順

my @arrImageFiles = ();		# 画像ファイルを格納する配列


my @arrFileScanMask = ('*.jpg', '*.jpeg', '*.png', '*.gif');	# 処理対象
my @arrKnownSuffix = ('.jpg', '.jpeg', '.png', '.gif');	# HTML出力時のファイル名で省略する拡張子

print("サムネイルHTML作成 Perlスクリプト (ver 1.1)\n\n");

sub_user_input_init();	# 初期データの入力
if(sub_confirm_init_data() != 1){
	die("終了（ユーザによるキャンセル）\n");
}

sub_scan_imagefiles();
sub_sort_imagefiles();

sub_disp_files();

sub_make_thumbnail();

sub_create_html();

#print Data::Dumper->Dumper(\@arrImageFiles)."\n";



print("正常終了\n");

exit();


# 初期データの入力
sub sub_user_input_init {

	# 基準ディレクトリの入力
	print("基準ディレクトリを、絶対または相対ディレクトリで入力。\n（例：/home/user/, ./）： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：ディレクトリが入力されませんでした）\n"); }
	if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
	unless(-d $_){ die("終了（理由：ディレクトリ ".$_." が存在しません）\n"); }
	$strBaseDir = $_;
	print("基準ディレクトリ : " . $strBaseDir . "\n");

	# 対象ディレクトリを限定する場合の入力
	print("画像があるディレクトリを限定する場合のディレクトリを入力\n改行のみで全てのディレクトリを対象とします（例：image/）： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){
		$strImageRelativeDir = undef;
		print("（基準ディレクトリ以下の）全てのディレクトリの画像ファイル対象とします\n");
	}
	else{
		if(substr($_,0,1) eq '/' || substr($_,0,2) eq './'){ die("終了（理由：/ や ./ で始まらない相対ディレクトリを入力してください）\n"); }
		if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
		unless(-d $strBaseDir.$_){ die("終了（理由：ディレクトリ ".$_." が存在しません）\n"); }
		$strImageRelativeDir = $_;
		print("画像ディレクトリの限定（基準ディレクトリからの相対） : " . $strImageRelativeDir . "\n");
	}

	# File::Find::Ruleでの検索深さの入力
	if(!defined($strImageRelativeDir)){
		print("画像ディレクトリの検索深さの開始値。基準ディレクトリを1とする。\n（デフォルト：2）： ");
		$_ = <STDIN>;
		chomp();
		if(length($_)<=0){ $_ = 2; }
		if(int($_)<1 || int($_)>10){ die("終了（入力範囲は 1 〜 10 です）\n"); }
		$nFindMinDepth = int($_);

		print("画像ディレクトリの検索深さの終了値。基準ディレクトリを1とする。\n（デフォルト：2）： ");
		$_ = <STDIN>;
		chomp();
		if(length($_)<=0){ $_ = 2; }
		if(int($_)<$nFindMinDepth || int($_)>10){ die("終了（入力範囲は $nFindMinDepth 〜 10 です）\n"); }
		$nFindMaxDepth = int($_);
	
		print("画像ディレクトリの検索深さ : $nFindMinDepth 〜 $nFindMaxDepth\n");
	}


	# サムネイル ディレクトリの入力（無い場合は、新規作成）
	print("サムネイル相対ディレクトリを入力（例：thumb/）： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：ディレクトリが入力されませんでした）\n"); }
	if(substr($_,0,1) eq '/' || substr($_,0,2) eq './'){ die("終了（理由：/ や ./ で始まらない相対ディレクトリを入力してください）\n"); }
	if(substr($_,-1) ne '/'){ $_ .= '/'; }	# ディレクトリは / で終わるように修正
	unless(-d $strBaseDir.$_){
		# サムネイル ディレクトリが存在しない場合は、新規作成する
		mkdir($strBaseDir.$_);
		unless(-d $strBaseDir.$_){ die("終了（理由：ディレクトリ ".$strBaseDir.$_." が作成できません）\n"); }
		print("サムネイル ディレクトリ新規作成（基準ディレクトリからの相対） : " . $_ . "\n");
	}
	else{
		print("既存のサムネイル ディレクトリ（基準ディレクトリからの相対） : " . $_ . "\n");
	}
	$strThumbRelativeDir = $_;

	# サムネイル画像のサイズを入力する
	print("サムネイル画像の長辺ピクセル（標準 180）： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $_ = 180; }
	if(int($_)<10 || int($_)>320){ die("終了（入力範囲は 10 〜 320 です）\n"); }
	$nLongEdge = int($_);
	print("サムネイルの長辺（px） : " . $nLongEdge . "\n");

	# サムネイル作成時の上書き設定
	print("サムネイル作成時に、ファイルがすでにある場合上書きする (y/N)：");
	$_ = <STDIN>;
	chomp();
	if(uc($_) eq 'Y'){
		$flag_overwrite = 1;
		print("既存のサムネイルファイルには上書きします\n");
	}
	elsif(uc($_) eq 'N' || length($_)<=0){
		$flag_overwrite = 0;
		print("既存のサムネイルファイルがある場合は、それを使います（上書き無し）\n");
	}
	else{
		die("終了（Y/Nの選択肢以外が入力された）\n");
	}

	# 出力HTMLファイル名の入力
	print("出力HTMLファイル名（例：index.html）： ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：ファイル名が入力されませんでした）\n"); }
	if($_ =~ /\//){ die("終了（理由：ファイル名に / が入っています）\n"); }
	if(-f $_ && -w $_){
		print("出力HTMLファイル名（上書き） : " . $_ . "\n");
	}
	elsif(-f $_){
		die("終了（理由：出力HTMLファイル " . $_ . " に書き込めません）\n");
	}
	else{
		print("出力HTMLファイル名（新規作成） : " . $_ . "\n");
	}
	$strOutputHTML = $_;


	# ソート順の選択
	print("ソート順を選択\n1: ファイル順（A...Z）\n2: ファイル順（Z...A）\n3: Exif/タイムスタンプ順（過去〜未来）\n4: Exif/タイムスタンプ順（未来〜過去）\n1〜4のいずれかを入力（デフォルト：1）：");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $_ = 1; }
	if(int($_)<1 || int($_)>4){ die("終了（入力範囲は 1 〜 4 です）\n"); }
	switch(int($_)){
		case 1	{ $flag_sort_order='file-name'; }
		case 2	{ $flag_sort_order='file-name-reverse'; }
		case 3	{ $flag_sort_order='file-date'; }
		case 4	{ $flag_sort_order='file-date-reverse'; }
		else	{ $flag_sort_order='file-name'; }
	}
	print("ソート順 : " . $flag_sort_order . "\n");


	# HTML形式の選択
	print("HTMLレイアウトの選択\n0: 1ファイル1行（説明文有り）\n2〜10: グリッド（横2枚〜10枚。説明文なし）\n0,2〜10のいずれかを入力（デフォルト：0）：");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ $_ = 0; }
	if(int($_)<0 || int($_)>10 || int($_)==1){ die("終了（入力範囲は 0,1 〜 10 です）\n"); }
	$nHtmlGrid = int($_);
	print("HTMLレイアウト グリッドの列数 : " . $nHtmlGrid . "\n");


}


# 初期設定の確認
sub sub_confirm_init_data {

	printf("\n===============\n".
		"基準ディレクトリ：%s\n".
		"画像ディレクトリ：%s\n".
		"%s".
		"サムネイルディレクトリ：%s\n".
		"サムネイル長辺：%d px\n".
		"サムネイル強制上書き：%s\n".
		"出力HTMLファイル名：./%s\n".
		"ソート順：%s\n",
		$strBaseDir,
		defined($strImageRelativeDir) ? $strBaseDir . $strImageRelativeDir : '全てのディレクトリ',
		defined($strImageRelativeDir) ? '' : '検索深さの設定：'.$nFindMinDepth.'〜'.$nFindMaxDepth."\n",
		$strBaseDir . $strThumbRelativeDir,
		$nLongEdge,
		$flag_overwrite == 1 ? 'ON' : 'OFF',
		$strOutputHTML,
		$flag_sort_order);

	# Y/N 確認
	print("この内容で処理しますか (y/N)：");
	$_ = <STDIN>;
	chomp();
	if(uc($_) eq 'Y'){
		return(1);
	}
	elsif(uc($_) eq 'N' || length($_)<=0){
		return(0);
	}
	else{
		die("終了（Y/Nの選択肢以外が入力された）\n");
	}

}


# 対象画像ファイルを配列に格納する
sub sub_scan_imagefiles {

	my @arrScan = undef;	# ファイル一覧を一時的に格納する配列
	my $tmpDate = undef;	# UNIX秒（ファイル/Exifのタイムスタンプ）
	my $exifTool = Image::ExifTool->new();
	$exifTool->Options(DateFormat => "%s", StrictDate=> 1);

	if(defined($strImageRelativeDir)){
		my $strScanPattern = '';
		foreach(@arrFileScanMask){
			if(length($strScanPattern)>1 && substr($strScanPattern,-1) ne ' '){$strScanPattern .= ' ';}
			$strScanPattern .= $strBaseDir.$strImageRelativeDir.$_;
		}
		@arrScan = glob($strScanPattern);
	}
	else{
		@arrScan = File::Find::Rule->file->name(@arrFileScanMask)->maxdepth($nFindMaxDepth)->mindepth($nFindMinDepth)->in($strBaseDir);
	}

	foreach(@arrScan)
	{
		if(length($_) <= 0){ next; }
		if($_ =~ /$strThumbRelativeDir/){ next; }
		$_ =~ s/^.\///g;	# 先頭の ./ を削除
		$exifTool->ImageInfo($_);
		$tmpDate = $exifTool->GetValue('CreateDate');
		if(!defined($tmpDate)){ $tmpDate = (stat($_))[9]; }	# Exifが無い場合は最終更新日
		my @arrTemp = ($_, dirname($_), basename($_), $tmpDate, 0, 0);
		push(@arrImageFiles, \@arrTemp);
	}

}


# 対象画像ファイルの配列をソートする
sub sub_sort_imagefiles {

	# まず、ディレクトリを A...Z でソートし、ディレクトリの内部を指定された条件でソートする

	switch($flag_sort_order){
		case 'file-name'	{
			@arrImageFiles = sort { @$a[1] cmp @$b[1] || @$a[2] cmp @$b[2] } @arrImageFiles;
		}
		case 'file-name-reverse'	{
			@arrImageFiles = sort { @$a[1] cmp @$b[1] || @$b[2] cmp @$a[2] } @arrImageFiles;
		}
		case 'file-date'	{
			@arrImageFiles = sort { @$a[1] cmp @$b[1] || @$a[3] cmp @$b[3] } @arrImageFiles;
		}
		case 'file-date-reverse'	{
			@arrImageFiles = sort { @$a[1] cmp @$b[1] || @$b[3] cmp @$a[3] } @arrImageFiles;
		}
	}

}

# 対象ファイルのデバッグ表示
sub sub_disp_files {

	if($flag_verbose == 1){
		foreach(@arrImageFiles){
			my @tm = localtime($_->[3]);
			printf("%s, %s, %s, %04d/%02d/%02d %02d:%02d:%02d\n", $_->[1], $_->[2], $_->[0],
				$tm[5]+1900, $tm[4]+1, $tm[3], $tm[2], $tm[1], $tm[0]);
		}
	}

	printf("対象画像が %d 個見つかりました\n", $#arrImageFiles);
}


# サムネイル画像の作成
sub sub_make_thumbnail {

	my $image = Image::Magick->new();
	my $image_check = undef;

	my $strFilenameInput = undef;
	my $strFilenameOutput = undef;

	print("サムネイル作成中 ...\n");

	eval{

		my $nCountWrite = 0;
		my $nCountSkip = 0;
		my $nCountError = 0;
		foreach(@arrImageFiles)
		{
			$strFilenameInput = $_->[0];


			chomp($strFilenameInput);
			if(length($strFilenameInput) <= 0){ next; }
			$strFilenameOutput = $strBaseDir . $strThumbRelativeDir . basename($strFilenameInput);

			if(-e $strFilenameOutput && $flag_overwrite == 0)
			{
				if($flag_verbose == 1){ print("サムネイル :" . $strFilenameOutput. " は既存\n"); }
				$nCountSkip++;
				next;
			}

			@$image = ();		# 読み込まれている画像をクリア

			$image_check = $image->Read($strFilenameInput);
			if($image_check)
			{
				print("\n画像ファイル :" . $strFilenameInput. " の読み込み不能\n");
				$nCountError++;
				next;
			}

			my ($nWidth, $nHeight) = $image->Get('width', 'height');
			if($nWidth <= 0 || $nHeight <= 0){ die("ジオメトリ読み込み失敗"); }
			my $nNewWidth = $nWidth > $nHeight ? $nLongEdge : int($nLongEdge*$nWidth/$nHeight);
			my $nNewHeight = $nHeight > $nWidth ? $nLongEdge : int($nLongEdge*$nHeight/$nWidth);

#			$image->AdaptiveResize(width=>$nNewWidth, height=>$nNewHeight);
			$image->Thumbnail(width=>$nNewWidth, height=>$nNewHeight);
			$image->Sharpen(radius=>0.0, sigma=>1.0);
			$image->Set(quality=>90);
			$image_check = $image->Write($strFilenameOutput);
			if($image_check)
			{
				print("\nサムネイル :" . $strFilenameOutput. " の書き込み不能\n");
				$nCountError++;
				next;
			}
			if($nCountWrite % 10 == 0){ print("作成中 ... ".$nCountWrite."\n"); }
			$nCountWrite++;

		}
		print("\nサムネイル作成処理 成功：".$nCountWrite.", 既存スキップ：".$nCountSkip.", エラー：".$nCountError."\n");

	};
	if($@){
		# evalによるエラートラップ：エラー時の処理
		print("プログラム エラー : ".$@."¥n");
		@$image = ();
		undef $image;
		exit();
	}

	@$image = ();
	undef $image;

}


# HTMLファイルの出力
sub sub_create_html {

	my $strFilenameInput = undef;
	my $strFilenameOutput = undef;

	print("出力HTMLファイル : ./" . $strOutputHTML . "\n");

	eval{	
		open(FH_OUT, ">$strOutputHTML") or die;

		printf(FH_OUT "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n" .
			"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"ja\" lang=\"ja\" dir=\"ltr\">\n" .
			"<head>\n" .
			"  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />\n" .
			"  <title></title>\n" .
			"  <style type=\"text/css\">\n<!--\n" .
			"  table {" .
			"      border:%dpx solid #aaa;" .
			"      border-collapse:collapse;" .
			"      font-size: 10pt;" .
			"      margin: 10px;" .
			"  }" .
			"  th {" .
			"      font-weight: normal;" .
			"      background:#f8ede2;" .
			"      border:%dpx solid #aaa;" .
			"      padding: 0.2em 0.4em;" .
			"  }" .
			"  td {" .
			"      border:%dpx solid #aaa;" .
			"      padding: 0.2em 0.4em;" .
			"  }" .
			"  a img {" .
			"      border: 0;" .
			"      margin: 0;" .
			"      padding: 0;" .
			"  }" .
			"-->\n  </style>\n" .
			"</head>\n" .
			"<body>\n" .
			"<p>%d files</p>\n" .
			"<table>\n",
			$nHtmlGrid == 0 ? 1 : 0,
			$nHtmlGrid == 0 ? 1 : 0,
			$nHtmlGrid == 0 ? 1 : 0,
			$#arrImageFiles);

		if($nHtmlGrid == 0) {
			printf(FH_OUT "  <tr><th>dir</th><th>file</th><th>thumbnail</th><th>time</th><th>comment 1</th><th>comment 2</th></tr>\n");
		
			foreach(@arrImageFiles)
			{
				$strFilenameInput = $_->[0];
				my @tm = localtime($_->[3]);
				chomp($strFilenameInput);
				if(length($strFilenameInput) <= 0){ next; }
				$strFilenameOutput = $strBaseDir . $strThumbRelativeDir . basename($strFilenameInput);
				my @arrSize = imgsize($strFilenameOutput);
				if(!defined($arrSize[0]) || !defined($arrSize[1])){ @arrSize = (0,0); }
				printf(FH_OUT "  <tr><td>%s</td><td>%s</td><td><a href=\"%s\"><img src=\"%s\" alt=\"\" width=\"%d\" height=\"%d\" /></a></td><td>%04d/%02d/%02d %02d:%02d:%02d</td><td></td><td></td></tr>\n",
					dirname($strFilenameInput),
					basename($strFilenameInput, @arrKnownSuffix),
					$strFilenameInput,
					$strFilenameOutput,
					$arrSize[0], $arrSize[1],
					$tm[5]+1900, $tm[4]+1, $tm[3], $tm[2], $tm[1], $tm[0]);

			}
		}
		else {
			my $i = 0;
			foreach(@arrImageFiles)
			{
				$strFilenameInput = $_->[0];
				chomp($strFilenameInput);
				if(length($strFilenameInput) <= 0){ next; }
				$strFilenameOutput = $strBaseDir . $strThumbRelativeDir . basename($strFilenameInput);
				my @arrSize = imgsize($strFilenameOutput);
				if(!defined($arrSize[0]) || !defined($arrSize[1])){ @arrSize = (0,0); }
				if($i == 0){ print(FH_OUT "  <tr>\n"); }
				printf(FH_OUT "    <td><a href=\"%s\"><img src=\"%s\" alt=\"\" width=\"%d\" height=\"%d\" /></a></td>\n",
					$strFilenameInput,
					$strFilenameOutput,
					$arrSize[0], $arrSize[1]);
				$i++;
				if($i >= $nHtmlGrid){
					print(FH_OUT "  </tr>\n");
					$i = 0;
				}
			}
			if($i != 0){ print(FH_OUT "  </tr>\n"); }
		}
		
		print(FH_OUT "</table>\n</body>\n</html>\n");

		close(FH_OUT);


	};
	if($@){
		# evalによるエラートラップ：エラー時の処理
		print("プログラム エラー : ".$@."¥n");
		exit();
	}


}


