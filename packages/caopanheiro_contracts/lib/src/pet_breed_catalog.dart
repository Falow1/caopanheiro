// GERADO por tool/generate-pet-breeds.mjs a partir de backend/src/pet_breeds.js.
// Não edite: altere a lista do backend e rode o gerador.
part of 'pet_breed.dart';

// código|nome|espécie|porte|tipo|ícone|outros;nomes
const _catalogData = r'''
srd-pequeno|SRD (vira-lata) – pequeno porte|Cachorro|Pequeno|SRD|srd-pequeno|vira-lata;viralata;vira lata;srd;sem raça;sem raça definida;mestiço;misturado;caramelo;vira-lata caramelo;não tem raça;sem pedigree
srd-medio|SRD (vira-lata) – médio porte|Cachorro|Médio|SRD|srd-medio-caramelo|vira-lata;viralata;vira lata;srd;sem raça;sem raça definida;mestiço;misturado;caramelo;vira-lata caramelo;não tem raça;sem pedigree
srd-grande|SRD (vira-lata) – grande porte|Cachorro|Grande|SRD|srd-grande|vira-lata;viralata;vira lata;srd;sem raça;sem raça definida;mestiço;misturado;caramelo;vira-lata caramelo;não tem raça;sem pedigree
outra-pequeno|Outra raça – pequeno porte|Cachorro|Pequeno|OTHER|outra-raca-cachorro|outra;outra raça;raça não listada;não está na lista
outra-medio|Outra raça – médio porte|Cachorro|Médio|OTHER|outra-raca-cachorro|outra;outra raça;raça não listada;não está na lista
outra-grande|Outra raça – grande porte|Cachorro|Grande|OTHER|outra-raca-cachorro|outra;outra raça;raça não listada;não está na lista
fila-brasileiro|Fila Brasileiro|Cachorro|Grande|BREED|fila-brasileiro|fila
terrier-brasileiro|Terrier Brasileiro (Fox Paulistinha)|Cachorro|Pequeno|BREED|terrier-brasileiro|fox paulistinha;foxinho;fox brasileiro;paulistinha
buldogue-campeiro|Buldogue Campeiro|Cachorro|Grande|BREED|buldogue-campeiro|bulldog campeiro;campeiro
dogue-brasileiro|Dogue Brasileiro|Cachorro|Grande|BREED|dogue-brasileiro|bull boxer brasileiro
ovelheiro-gaucho|Ovelheiro Gaúcho|Cachorro|Médio|BREED|ovelheiro-gaucho|ovelheiro
affenpinscher|Affenpinscher|Cachorro|Pequeno|BREED|affenpinscher|affen
bichon-frise|Bichon Frisé|Cachorro|Pequeno|BREED|bichon-frise|bichon;bichon frise
bichon-havanes|Bichon Havanês|Cachorro|Pequeno|BREED|bichon-havanes|havanês;havanese
boston-terrier|Boston Terrier|Cachorro|Pequeno|BREED|boston-terrier|boston
buldogue-frances|Buldogue Francês|Cachorro|Pequeno|BREED|buldogue-frances|bulldog francês;buldog francês;bulldog frances;french bulldog;frenchie;buldogue frances
cavalier-king-charles|Cavalier King Charles Spaniel|Cachorro|Pequeno|BREED|cavalier-king-charles|cavalier;king charles
chihuahua-pelo-curto|Chihuahua de pelo curto|Cachorro|Pequeno|BREED|chihuahua-pelo-curto|chihuahua;chiuaua;chihuaua;chiwawa
chihuahua-pelo-longo|Chihuahua de pelo longo|Cachorro|Pequeno|BREED|chihuahua-pelo-longo|chihuahua;chiuaua;chihuaua;chiwawa
coton-de-tulear|Coton de Tuléar|Cachorro|Pequeno|BREED|coton-de-tulear|coton
dachshund-pelo-curto|Dachshund (salsicha) de pelo curto|Cachorro|Pequeno|BREED|dachshund-pelo-curto|dachshund;salsicha;teckel;cofap;daschund;dachshound
dachshund-pelo-longo|Dachshund (salsicha) de pelo longo|Cachorro|Pequeno|BREED|dachshund-pelo-longo|dachshund;salsicha;teckel;cofap;daschund;dachshound
dachshund-pelo-duro|Dachshund (salsicha) de pelo duro|Cachorro|Pequeno|BREED|dachshund-pelo-duro|dachshund;salsicha;teckel;cofap;daschund;dachshound
griffon-de-bruxelas|Griffon de Bruxelas|Cachorro|Pequeno|BREED|griffon-de-bruxelas|griffon;grifon
jack-russell-terrier|Jack Russell Terrier|Cachorro|Pequeno|BREED|jack-russell-terrier|jack russell;jack russel;jack
lhasa-apso|Lhasa Apso|Cachorro|Pequeno|BREED|lhasa-apso|lhasa;lasa;lasa apso;lhasa apso
lulu-da-pomerania|Lulu da Pomerânia (Spitz Alemão Anão)|Cachorro|Pequeno|BREED|lulu-da-pomerania|lulu;pomerania;pomeranian;spitz alemão;spitz alemão anão;spitz;lulu da pomerania
maltes|Maltês|Cachorro|Pequeno|BREED|maltes|maltes;maltese;bichon maltês
papillon|Papillon|Cachorro|Pequeno|BREED|papillon|papilon
pequines|Pequinês|Cachorro|Pequeno|BREED|pequines|pequines;pekingese
pinscher-miniatura|Pinscher Miniatura|Cachorro|Pequeno|BREED|pinscher-miniatura|pinscher;pincher;pinsher;pinscher zero;pinscher 1;pinscher 2
pug|Pug|Cachorro|Pequeno|BREED|pug|pug
west-highland-white-terrier|West Highland White Terrier|Cachorro|Pequeno|BREED|west-highland-white-terrier|westie;west highland;west terrier
cairn-terrier|Cairn Terrier|Cachorro|Pequeno|BREED|cairn-terrier|cairn
scottish-terrier|Scottish Terrier|Cachorro|Pequeno|BREED|scottish-terrier|scottie;terrier escocês
fox-terrier|Fox Terrier|Cachorro|Pequeno|BREED|fox-terrier|fox
spitz-japones|Spitz Japonês|Cachorro|Pequeno|BREED|spitz-japones|spitz japones;japanese spitz
galgo-italiano|Galgo Italiano|Cachorro|Pequeno|BREED|galgo-italiano|italian greyhound;piccolo levriero
cao-de-crista-chines|Cão de Crista Chinês|Cachorro|Pequeno|BREED|cao-de-crista-chines|crista chinês;chinese crested;cão chinês de crista
yorkshire-terrier|Yorkshire Terrier|Cachorro|Pequeno|BREED|yorkshire-terrier|yorkshire;york;yorkie;yorkshire terrier
poodle-toy|Poodle Toy|Cachorro|Pequeno|BREED|poodle|poodle;poodle micro toy;micro toy;caniche;poodle toy
poodle-anao|Poodle Anão (Miniatura)|Cachorro|Pequeno|BREED|poodle|poodle;poodle miniatura;poodle mini;caniche;poodle anao
poodle-medio|Poodle Médio|Cachorro|Médio|BREED|poodle|poodle;caniche;poodle medio
poodle-gigante|Poodle Gigante (Standard)|Cachorro|Grande|BREED|poodle|poodle;poodle standard;poodle padrão;caniche
schnauzer-miniatura|Schnauzer Miniatura|Cachorro|Pequeno|BREED|schnauzer|schnauzer;schnauzer mini;schnauser;chinauzer;snauzer
schnauzer-standard|Schnauzer Standard (Médio)|Cachorro|Médio|BREED|schnauzer|schnauzer;schnauzer médio;schnauser;chinauzer;snauzer
shih-tzu|Shih Tzu|Cachorro|Pequeno|BREED|shih-tzu|shitzu;shih tzu;shitsu;chitsu;shi tzu;xitsu
shiba-inu|Shiba Inu|Cachorro|Médio|BREED|shiba-inu|shiba
pastor-de-shetland|Pastor de Shetland|Cachorro|Pequeno|BREED|pastor-de-shetland|sheltie;shetland
welsh-corgi-pembroke|Welsh Corgi Pembroke|Cachorro|Médio|BREED|welsh-corgi-pembroke|corgi;welsh corgi
beagle|Beagle|Cachorro|Médio|BREED|beagle|beagle;bigle;biguel
cocker-spaniel-ingles|Cocker Spaniel Inglês|Cachorro|Médio|BREED|cocker-spaniel-ingles|cocker;cocker inglês;cocker spaniel
cocker-spaniel-americano|Cocker Spaniel Americano|Cachorro|Médio|BREED|cocker-spaniel-americano|cocker;cocker americano;cocker spaniel
basenji|Basenji|Cachorro|Médio|BREED|basenji|basenji
american-pit-bull-terrier|Pit Bull (American Pit Bull Terrier)|Cachorro|Médio|BREED|american-pit-bull-terrier|pit bull;pitbull;pit;american pit bull
american-staffordshire-terrier|American Staffordshire Terrier|Cachorro|Médio|BREED|american-staffordshire-terrier|amstaff;staffordshire;american staffordshire
staffordshire-bull-terrier|Staffordshire Bull Terrier|Cachorro|Médio|BREED|staffordshire-bull-terrier|staffbull;staffy;staffordshire bull
american-bully|American Bully|Cachorro|Grande|BREED|american-bully|bully;american bully
bull-terrier|Bull Terrier|Cachorro|Grande|BREED|bull-terrier|bull terrier;bulterrier
bull-terrier-miniatura|Bull Terrier Miniatura|Cachorro|Médio|BREED|bull-terrier|bull terrier;bull terrier mini;bulterrier
buldogue-ingles|Buldogue Inglês|Cachorro|Médio|BREED|buldogue-ingles|bulldog inglês;buldog inglês;bulldog ingles;english bulldog;bulldog;buldogue
buldogue-americano|Buldogue Americano|Cachorro|Grande|BREED|buldogue-americano|bulldog americano;american bulldog;buldog americano
basset-hound|Basset Hound|Cachorro|Médio|BREED|basset-hound|basset;baset
border-collie|Border Collie|Cachorro|Médio|BREED|border-collie|border;border colie
pastor-australiano|Pastor Australiano|Cachorro|Médio|BREED|pastor-australiano|australian shepherd;aussie
boiadeiro-australiano|Boiadeiro Australiano|Cachorro|Médio|BREED|boiadeiro-australiano|blue heeler;red heeler;cattle dog;heeler
chow-chow|Chow Chow|Cachorro|Médio|BREED|chow-chow|chow;chowchow;chau chau
shar-pei|Shar-pei|Cachorro|Médio|BREED|shar-pei|sharpei;shar pei;xarpei
husky-siberiano|Husky Siberiano|Cachorro|Médio|BREED|husky-siberiano|husky;huski;raski;siberian husky
samoieda|Samoieda|Cachorro|Médio|BREED|samoieda|samoyed;samoeida
springer-spaniel-ingles|Springer Spaniel Inglês|Cachorro|Médio|BREED|springer-spaniel-ingles|springer
whippet|Whippet|Cachorro|Médio|BREED|whippet|whipet;uipet
dalmata|Dálmata|Cachorro|Grande|BREED|dalmata|dalmata;dalmatian
schnauzer-gigante|Schnauzer Gigante|Cachorro|Grande|BREED|schnauzer-gigante|schnauzer;giant schnauzer;schnauser
vizsla|Vizsla|Cachorro|Médio|BREED|vizsla|braco húngaro;visla
pointer-ingles|Pointer Inglês|Cachorro|Grande|BREED|pointer-ingles|pointer
setter-irlandes|Setter Irlandês|Cachorro|Grande|BREED|setter-irlandes|setter;irish setter
weimaraner|Weimaraner|Cachorro|Grande|BREED|weimaraner|weimaraner;braco de weimar;vaimaraner
collie|Collie (pelo longo)|Cachorro|Grande|BREED|collie|collie;colie;lassie;rough collie
bobtail|Bobtail (Old English Sheepdog)|Cachorro|Grande|BREED|bobtail|old english sheepdog;bob tail
pastor-belga-malinois|Pastor Belga Malinois|Cachorro|Grande|BREED|pastor-belga-malinois|malinois;pastor belga;malinoa
boxer|Boxer|Cachorro|Grande|BREED|boxer|boxer;boxe
labrador-retriever|Labrador Retriever|Cachorro|Grande|BREED|labrador-retriever|labrador;lab;labrador retriever
golden-retriever|Golden Retriever|Cachorro|Grande|BREED|golden-retriever|golden;golden retriver
pastor-alemao|Pastor Alemão|Cachorro|Grande|BREED|pastor-alemao|pastor;capa preta;german shepherd;pastor alemao
pastor-branco-suico|Pastor Branco Suíço|Cachorro|Grande|BREED|pastor-branco-suico|pastor branco;pastor alemão branco;white swiss shepherd
rottweiler|Rottweiler|Cachorro|Grande|BREED|rottweiler|rottweiler;rotweiler;rottweiller;rot;rotwailer
doberman|Dobermann|Cachorro|Grande|BREED|doberman|doberman;dobermam;dobermann
dogue-alemao|Dogue Alemão|Cachorro|Grande|BREED|dogue-alemao|dog alemão;great dane;dinamarquês;dogue alemao
dogue-de-bordeaux|Dogue de Bordeaux|Cachorro|Grande|BREED|dogue-de-bordeaux|bordeaux;dog de bordeaux;mastim francês
mastim-ingles|Mastim Inglês|Cachorro|Grande|BREED|mastim-ingles|mastiff;mastiff inglês
mastim-napolitano|Mastim Napolitano|Cachorro|Grande|BREED|mastim-napolitano|napolitano;mastino napoletano
cane-corso|Cane Corso|Cachorro|Grande|BREED|cane-corso|corso;cane corso italiano
dogo-argentino|Dogo Argentino|Cachorro|Grande|BREED|dogo-argentino|dogo;dogo argentino
boiadeiro-bernes|Boiadeiro Bernês|Cachorro|Grande|BREED|boiadeiro-bernes|bernês;bernese;bernese mountain dog;boiadeiro bernes
sao-bernardo|São Bernardo|Cachorro|Grande|BREED|sao-bernardo|sao bernardo;saint bernard;são bernardo
terra-nova|Terra Nova|Cachorro|Grande|BREED|terra-nova|newfoundland;terranova
akita-inu|Akita Inu|Cachorro|Grande|BREED|akita-inu|akita;akita japonês
akita-americano|Akita Americano|Cachorro|Grande|BREED|akita-americano|akita;american akita
malamute-do-alasca|Malamute do Alasca|Cachorro|Grande|BREED|malamute-do-alasca|malamute;alaskan malamute
rhodesian-ridgeback|Rhodesian Ridgeback|Cachorro|Grande|BREED|rhodesian-ridgeback|rhodesian;ridgeback
galgo-ingles|Galgo Inglês (Greyhound)|Cachorro|Grande|BREED|galgo-ingles|greyhound;galgo;grey hound
galgo-afegao|Galgo Afegão|Cachorro|Grande|BREED|galgo-afegao|afghan hound;afegão;galgo afegao
leonberger|Leonberger|Cachorro|Grande|BREED|leonberger|leonberg
bullmastiff|Bullmastiff|Cachorro|Grande|BREED|bullmastiff|bull mastiff
bloodhound|Bloodhound (Cão de Santo Humberto)|Cachorro|Grande|BREED|bloodhound|cão de santo humberto;blood hound;santo humberto
mastim-tibetano|Mastim Tibetano|Cachorro|Grande|BREED|mastim-tibetano|tibetan mastiff;mastiff tibetano
gato-srd|SRD (vira-lata)|Gato|Pequeno|SRD|srd-gato|vira-lata;viralata;vira lata;srd;sem raça;sem raça definida;mestiço;misturado;rajado;tigrado;comum;gato de rua;não tem raça;sem pedigree
gato-srd-frajola|SRD frajola (preto e branco)|Gato|Pequeno|SRD|srd-gato-frajola|frajola;preto e branco;srd frajola
gato-outra|Outra raça|Gato|Pequeno|OTHER|outra-raca-gato|outra;outra raça;raça não listada;não está na lista
persa|Persa|Gato|Pequeno|BREED|persa|persian
himalaio|Himalaio|Gato|Pequeno|BREED|himalaio|himalaia;himalayan
exotico|Exótico de Pelo Curto|Gato|Pequeno|BREED|exotico|exótico;exotic;exotic shorthair;persa de pelo curto
siames|Siamês|Gato|Pequeno|BREED|siames|siames;siamese
maine-coon|Maine Coon|Gato|Médio|BREED|maine-coon|mainecoon;maine;mei coon
angora|Angorá Turco|Gato|Pequeno|BREED|angora|angorá;angora;turkish angora
ragdoll|Ragdoll|Gato|Pequeno|BREED|ragdoll|rag doll
sagrado-da-birmania|Sagrado da Birmânia|Gato|Pequeno|BREED|sagrado-da-birmania|birmanês;birman;sagrado;sagrado da birmania
british-shorthair|British Shorthair|Gato|Pequeno|BREED|british-shorthair|british;britânico
azul-russo|Azul Russo|Gato|Pequeno|BREED|azul-russo|russian blue;russo
chartreux|Chartreux|Gato|Pequeno|BREED|chartreux|cartuxo
sphynx|Sphynx|Gato|Pequeno|BREED|sphynx|sphinx;esfinge;pelado;sem pelo
bengal|Bengal|Gato|Pequeno|BREED|bengal|bengala;bengal
savannah|Savannah|Gato|Pequeno|BREED|savannah|savana;savanah
mau-egipcio|Mau Egípcio|Gato|Pequeno|BREED|mau-egipcio|egyptian mau;mau egipcio
abissinio|Abissínio|Gato|Pequeno|BREED|abissinio|abyssinian;abissinio
scottish-fold|Scottish Fold|Gato|Pequeno|BREED|scottish-fold|scottish;fold;orelha dobrada
devon-rex|Devon Rex|Gato|Pequeno|BREED|devon-rex|devon
cornish-rex|Cornish Rex|Gato|Pequeno|BREED|cornish-rex|cornish
noruegues-da-floresta|Norueguês da Floresta|Gato|Pequeno|BREED|noruegues-da-floresta|norwegian forest;norueguês;noruegues da floresta
siberiano|Siberiano|Gato|Pequeno|BREED|siberiano|siberian
american-shorthair|American Shorthair|Gato|Pequeno|BREED|american-shorthair|americano de pelo curto
oriental|Oriental de Pelo Curto|Gato|Pequeno|BREED|oriental|oriental
bombay|Bombay|Gato|Pequeno|BREED|bombay|bombaim
munchkin|Munchkin|Gato|Pequeno|BREED|munchkin|munchikin;manchkin
''';
