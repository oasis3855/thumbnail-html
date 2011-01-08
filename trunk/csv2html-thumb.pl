#!/usr/bin/perl
 
# Linux : save this file in << UTF-8  >> encode !
# Windows : save this file in << Shift-JIS  >> encode !
# ******************************************************
# Software name : Make Thumbnail HTML （サムネイルHTML作成）
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# csv2html-thumb.pl
# version 0.1 (2010/December/14)
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

use Switch;	# select case ...
use Image::Size;	# サムネイル画像のxyサイズを読み出すときに利用
use Image::ExifTool;	# Exifデータの日時を読み出すときに利用
use Image::Magick;	# サムネイル画像作成（画像縮小）で利用
use File::Basename;
use Text::CSV_XS;
use Data::Dumper;

my $strCsvFilename = '';	# 入力CSVファイル名
my $strHTMLFilename = '';	# 出力HTMLファイル名
my $nTargetFiles = 0;		# CSV内のデータ行数
my @arrImageFiles = ();		# CSVから読み込んだ配列
my $nHtmlGrid = 0;		# HTMLのグリッドカラム数（0は説明文付き1列）
my $nLongEdge = 180;		# サムネイルの長辺ピクセル数（ImageMagickで縮小時に利用）

my $flag_overwrite = 0;		# サムネイルを作成するときに、既存ファイルに上書きするフラグ
my $flag_exif_read = 0;		# CSVに格納されている日時を無視して、画像ファイルから再読込する
my $flag_verbose = 0;		# 詳細表示するフラグ
my $flag_sort_order = 'file-name';	# ソート順


my @arrKnownSuffix = ('.jpg', '.jpeg', '.png', '.gif');	# HTML出力時のファイル名で省略する拡張子


print("\n".basename($0)." : CSV形式の写真管理データを、HTML形式に書き戻します\n".
	"（入力ファイルはこのスクリプトと同じエンコード形式の必要があります）\n\n");


sub_user_input_init();

sub_read_from_csv();
sub_sort_imagefiles();

sub_make_thumbnail();

sub_create_html();

print "終了\n";

exit();

# 初期データの入力
sub sub_user_input_init {

	# インポートする CSV ファイル名
	print("インポートするデータが入ったCSVファイル名を入力 : ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：ファイル名が入力されませんでした）\n"); }
	unless(-f $_){ die("終了（理由：ファイル ".$_." が存在しません）\n"); }
	$strCsvFilename = $_;
	print("入力CSVファイル名 : " . $strCsvFilename . "\n");


	# エクスポートする HTML ファイル名
	print("出力するHTMLファイル名を入力（カレントディレクトリ内） : ");
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
	$strHTMLFilename = $_;
	print("出力HTMLファイル名 : " . $strHTMLFilename . "\n");

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

	printf("画像ファイルのExif日時を優先する (Y/N) [N] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0){  $flag_exif_read = 0; }
	elsif(uc($_) eq 'Y'){ $flag_exif_read = 1; }
	else {$flag_exif_read = 0; }

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


}


# CSVファイルからデータを読み込んで、配列に格納する
# 
# CSVデータの形式："a href","img src", "unix date", "comment1", "comment2"
#
sub sub_read_from_csv {

	my $csv = Text::CSV_XS->new({binary=>1});
	my $exifTool = Image::ExifTool->new();
	$exifTool->Options(DateFormat => "%s", StrictDate=> 1);

	open(FH_IN, "<$strCsvFilename") or die("ファイル $strCsvFilename を読み込めません");
	$nTargetFiles = 0;
	while(<FH_IN>)
	{
		# CSV各行をパースして、ファイル名とコメントを配列$arrFileAndCommentに格納
		my $strLine = $_;
		if($strLine eq ''){ next; }
		$csv->parse($strLine) or next;
		my @arrFields = $csv->fields();
		if($#arrFields < 1){ next; }		# 要素数2以下のときはスキップ
		my @arrTemp = ($arrFields[0],		# [0]:画像ファイル名（dir + basename)
				dirname($arrFields[0]),	# [1]:画像ファイルのdir
				basename($arrFields[0], @arrKnownSuffix),	# [2]:画像ファイルのbasename
				$arrFields[1],		# [3]:サムネイルファイル名 (dir + basename)
				defined($arrFields[2]) ? $arrFields[2] : 0,	# [4]:unix時間
				defined($arrFields[3]) ? $arrFields[3] : '',	# [5]:comment1
				defined($arrFields[4]) ? $arrFields[4] : ''	# [6]:comment2
				);
		$arrTemp[5] =~ s/<br>/<br \/>/g;		# <br>→<br />
		$arrTemp[6] =~ s/<br>/<br \/>/g;		# <br>→<br />

		# 画像ファイルからExif日時を読み込む
		if($flag_exif_read == 1 && (-f $arrTemp[0]))
		{
			$exifTool->ImageInfo($arrTemp[0]);
			my $tmpDate = $exifTool->GetValue('CreateDate');
#			if(!defined($tmpDate)){ $tmpDate = (stat($_))[9]; }	# Exifが無い場合は最終更新日
			if(defined($tmpDate)){ $arrTemp[4] = $tmpDate; }
		}

		push(@arrImageFiles, \@arrTemp);
		$nTargetFiles++;
	}
	close(FH_IN) or die("ファイル $strCsvFilename を close 出来ませんでした");

	### CSVから読み込んだデータの画面表示
	printf("CSVから読み込み完了。データ行数 = %d\n", $nTargetFiles);
	if($flag_verbose != 0)
	{
		print Data::Dumper->Dumper(\@arrImageFiles)."\n";
		my $i;
		for($i=0; $i<$nTargetFiles; $i++){
			print $arrImageFiles[$i][0]."\n";
		}
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
			@arrImageFiles = sort { @$a[1] cmp @$b[1] || @$a[4] cmp @$b[4] } @arrImageFiles;
		}
		case 'file-date-reverse'	{
			@arrImageFiles = sort { @$a[1] cmp @$b[1] || @$b[4] cmp @$a[4] } @arrImageFiles;
		}
	}

}


# HTMLファイルの出力
sub sub_create_html {

	my $strFilenameInput = undef;
	my $strFilenameOutput = undef;

	print("出力HTMLファイル : ./" . $strHTMLFilename . "\n");

	eval{	
		open(FH_OUT, ">$strHTMLFilename") or die;

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
			$#arrImageFiles+1);

		if($nHtmlGrid == 0) {
			printf(FH_OUT "  <tr><th>dir</th><th>file</th><th>thumbnail</th><th>time</th><th>comment 1</th><th>comment 2</th></tr>\n");
		
			foreach(@arrImageFiles)
			{
				my @arrSize = imgsize($_->[3]);	# サムネイル画像の x,y ピクセル
				if(!defined($arrSize[0]) || !defined($arrSize[1])){ @arrSize = (0,0); }
				my @tm = localtime($_->[4]);
				my $strDateTime = sprintf("%04d/%02d/%02d<br />%02d:%02d:%02d",
					$tm[5]+1900, $tm[4]+1, $tm[3], $tm[2], $tm[1], $tm[0]);
				printf(FH_OUT "  <tr><td>%s</td><td>%s</td><td><a href=\"%s\"><img src=\"%s\" alt=\"\" width=\"%d\" height=\"%d\" /></a></td><td>%s</td><td>%s</td><td>%s</td></tr>\n",
					$_->[1],	# dirname
					$_->[2],	# basename
					$_->[0],	# 画像ファイル a href=
					$_->[3],	# サムネイルファイル img src=
					$arrSize[0], $arrSize[1],
					$strDateTime,	# 日時
					$_->[5],	# comment 1
					$_->[6]	# comment 2
					);

			}
		}
		else {
			my $i = 0;
			foreach(@arrImageFiles)
			{
				my @arrSize = imgsize($_->[3]);	# サムネイル画像の x,y ピクセル
				if(!defined($arrSize[0]) || !defined($arrSize[1])){ @arrSize = (0,0); }
				if($i == 0){ print(FH_OUT "  <tr>\n"); }
				printf(FH_OUT "    <td><a href=\"%s\"><img src=\"%s\" width=\"%d\" height=\"%d\" alt=\"%s\" /></a></td>\n",
					$_->[0],	# 画像ファイル a herf=
					$_->[3],	# サムネイルファイル img src=
					$arrSize[0], $arrSize[1],
					$_->[6]	# comment 2 → alt=
					);
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


# サムネイル画像の作成
# （拙作 thumbnail-dir.pl の関数を流用）
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
			$strFilenameInput = $_->[0];		# 画像ファイル（フルサイズ）
			$strFilenameOutput = $_->[3];	# サムネイル画像ファイル


			if(-f $strFilenameOutput && $flag_overwrite == 0)
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



